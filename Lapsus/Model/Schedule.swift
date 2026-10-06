import Foundation

/// Horario de un día de la semana. Las horas van en minutos desde la medianoche.
struct DayPlan: Codable, Equatable {
    var enabled: Bool
    var start: Int
    var end: Int
    /// Descanso no laborable dentro del horario (almuerzo).
    var breakMinutes: Int

    /// Minutos de trabajo esperados: es la meta del día.
    var minutes: Int { enabled ? max(0, end - start - breakMinutes) : 0 }

    /// El horario tiene sentido (termina después de empezar y cabe el descanso).
    var isValid: Bool { !enabled || end - start - breakMinutes > 0 }

    static let workday = DayPlan(enabled: true, start: 8 * 60, end: 17 * 60, breakMinutes: 60)
    static let dayOff = DayPlan(enabled: false, start: 8 * 60, end: 17 * 60, breakMinutes: 60)
}

/// Horario semanal: cada día con el suyo.
struct WorkSchedule: Codable, Equatable {
    /// Índice 0 = lunes … 6 = domingo.
    var days: [DayPlan]

    static let standard = WorkSchedule(days: (0..<7).map { $0 < 5 ? DayPlan.workday : DayPlan.dayOff })

    init(days: [DayPlan]) {
        self.days = days
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var list = try c.decodeIfPresent([DayPlan].self, forKey: .days) ?? WorkSchedule.standard.days
        // Siempre 7 días, pase lo que pase con lo guardado.
        if list.count < 7 { list += WorkSchedule.standard.days.suffix(7 - list.count) }
        days = Array(list.prefix(7))
    }

    /// 0 = lunes … 6 = domingo.
    static func index(of date: Date) -> Int {
        (Fmt.cal.component(.weekday, from: date) + 5) % 7
    }

    func plan(for date: Date) -> DayPlan {
        days[Self.index(of: date)]
    }

    var weeklyMinutes: Int { days.reduce(0) { $0 + $1.minutes } }
    var workDays: Int { days.filter { $0.enabled && $0.minutes > 0 }.count }

    /// "L–V 08:00–17:00" si todos los días activos son iguales; si no, "5 días · 40 h".
    func summary(use24h: Bool) -> String {
        let active = days.enumerated().filter { $0.element.enabled }
        guard let first = active.first?.element else { return "Sin horario" }
        let sameHours = active.allSatisfy { $0.element.start == first.start && $0.element.end == first.end }
        let idx = active.map(\.offset)
        let consecutive = idx == Array((idx.first ?? 0)...(idx.last ?? 0))
        if sameHours && consecutive {
            let range = idx.count == 1
                ? Fmt.weekInitials[idx[0]]
                : "\(Fmt.weekInitials[idx.first ?? 0])–\(Fmt.weekInitials[idx.last ?? 0])"
            return "\(range) \(Fmt.clockTime(first.start, use24h))–\(Fmt.clockTime(first.end, use24h))"
        }
        return "\(workDays) días · \(Fmt.hm(Double(weeklyMinutes) * 60)) a la semana"
    }
}
