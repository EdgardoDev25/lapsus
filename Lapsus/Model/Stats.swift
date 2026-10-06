import SwiftUI

/// Números de un día para gráficos y comparativas.
struct DayStat: Identifiable {
    var id: String
    var date: Date
    var focused: TimeInterval
    var paused: TimeInterval
    var overtime: TimeInterval
    var distraction: TimeInterval
    var ratio: Double?
    var longest: TimeInterval
    var counts: Bool
    /// Meta de ese día según el horario que tenía entonces (0 = día libre).
    var goal: TimeInterval

    var distractionShare: Double {
        let total = focused + paused
        return total > 0 ? distraction / total : 0
    }
}

struct PauseSlice: Identifiable {
    var id: String
    var name: String
    var color: Color
    var seconds: TimeInterval
}

struct WeekStats {
    var start: Date
    var days: [DayStat]

    var worked: [DayStat] { days.filter { $0.counts } }
    var focused: TimeInterval { worked.reduce(0) { $0 + $1.focused } }
    var paused: TimeInterval { worked.reduce(0) { $0 + $1.paused } }
    var overtime: TimeInterval { days.reduce(0) { $0 + $1.overtime } }
    var distraction: TimeInterval { worked.reduce(0) { $0 + $1.distraction } }
    var longest: TimeInterval { days.map(\.longest).max() ?? 0 }
    var ratio: Double? {
        focused + paused > 0 ? focused / (focused + paused) : nil
    }
    var hasData: Bool { !worked.isEmpty }

    /// Suma de las metas de los días trabajados que eran laborables.
    var goal: TimeInterval { worked.filter { $0.goal > 0 }.reduce(0) { $0 + $1.goal } }
    /// Qué tanto de esa meta se cumplió (los días libres no cuentan).
    var goalShare: Double? {
        let g = goal
        guard g > 0 else { return nil }
        let f = worked.filter { $0.goal > 0 }.reduce(0) { $0 + $1.focused }
        return f / g
    }

    var best: DayStat? {
        worked.count >= 2 ? worked.max(by: { $0.focused < $1.focused }) : nil
    }
    var worst: DayStat? {
        worked.count >= 3 ? worked.min(by: { $0.focused < $1.focused }) : nil
    }

    /// Tiempo en pausa por grupo y por categoría (una pausa con varias
    /// categorías reparte su duración entre ellas).
    var byGroup: [PauseSlice] = []
    var byCategory: [PauseSlice] = []
}

enum Stats {
    static func weekStart(_ date: Date) -> Date {
        Fmt.cal.dateInterval(of: .weekOfYear, for: date)?.start ?? Fmt.cal.startOfDay(for: date)
    }

    static func dayStat(_ d: WorkDay, now: Date = Date()) -> DayStat {
        var distraction: TimeInterval = 0
        for p in d.pauses where p.kind == .normal && !p.categories.isEmpty {
            let share = p.duration(now: now) / Double(p.categories.count)
            for c in p.categories where PauseCategory.byID[c]?.weight.isDistraction == true {
                distraction += share
            }
        }
        return DayStat(id: d.id, date: d.date,
                       focused: d.focused(.normal, now: now),
                       paused: d.paused(.normal, now: now),
                       overtime: d.focused(.overtime, now: now),
                       distraction: distraction,
                       ratio: d.focusRatio(.normal, now: now),
                       longest: d.longestBlock(now: now),
                       counts: d.counts,
                       goal: Double(d.goalMinutes) * 60)
    }

    static func week(_ start: Date, days: [WorkDay], now: Date = Date()) -> WeekStats {
        let byID = Dictionary(days.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var stats: [DayStat] = []
        var groupSecs: [PauseGroup: TimeInterval] = [:]
        var catSecs: [String: TimeInterval] = [:]

        for i in 0..<7 {
            let date = Fmt.cal.date(byAdding: .day, value: i, to: start) ?? start
            let id = Fmt.dayID(date)
            if let d = byID[id] {
                stats.append(dayStat(d, now: now))
                guard d.counts else { continue }
                for p in d.pauses where !p.categories.isEmpty {
                    let share = p.duration(now: now) / Double(p.categories.count)
                    for c in p.categories {
                        guard let cat = PauseCategory.byID[c] else { continue }
                        groupSecs[cat.group, default: 0] += share
                        catSecs[c, default: 0] += share
                    }
                }
            } else {
                stats.append(DayStat(id: id, date: date, focused: 0, paused: 0, overtime: 0, distraction: 0,
                                     ratio: nil, longest: 0, counts: false, goal: 0))
            }
        }

        var w = WeekStats(start: start, days: stats)
        w.byGroup = groupSecs
            .map { PauseSlice(id: $0.key.rawValue, name: $0.key.name, color: $0.key.color, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
        w.byCategory = catSecs
            .compactMap { kv -> PauseSlice? in
                guard let c = PauseCategory.byID[kv.key] else { return nil }
                return PauseSlice(id: c.id, name: c.short, color: c.group.color, seconds: kv.value)
            }
            .sorted { $0.seconds > $1.seconds }
        return w
    }

    /// Días trabajados seguidos cumpliendo la meta. Los días sin registro y los
    /// días libres según el horario no rompen la racha. Hoy solo suma si ya se cumplió.
    static func streak(_ days: [WorkDay]) -> Int {
        let todayID = Fmt.dayID(Date())
        var count = 0
        for d in days.reversed() where d.counts && d.hasGoal {
            if d.metGoal {
                count += 1
            } else if d.id == todayID {
                continue
            } else {
                break
            }
        }
        return count
    }

    /// Frases automáticas basadas en reglas. Sin internet ni IA.
    static func insights(_ w: WeekStats, previous p: WeekStats) -> [String] {
        var out: [String] = []

        if let best = w.best {
            let day = Fmt.weekdays[Fmt.cal.component(.weekday, from: best.date)].lowercased()
            out.append("Tu día más productivo fue el \(day): \(Fmt.hoursDecimal(best.focused)) enfocado y solo \(Fmt.percent(best.distractionShare)) en distracciones.")
        }

        if let r = w.ratio, let pr = p.ratio {
            let delta = Int(((r - pr) * 100).rounded())
            if delta >= 3 {
                out.append("Esta semana tu focus ratio mejoró \(delta)% respecto a la anterior.")
            } else if delta <= -3 {
                out.append("Tu focus ratio bajó \(-delta)% respecto a la semana anterior. ¿Mucho ruido estos días?")
            }
        }

        if let worst = w.worst, let top = topDistraction(w), worst.distractionShare > 0.1 {
            let day = Fmt.weekdays[Fmt.cal.component(.weekday, from: worst.date)].lowercased()
            out.append("El \(day) fue tu día más flojo; lo que más tiempo se llevó esta semana fue \(top.lowercased()).")
        }

        if out.isEmpty, w.hasData {
            out.append("Vas \(Fmt.hm(w.focused)) enfocado esta semana. Sigue registrando tus pausas para ver patrones.")
        }
        return out
    }

    private static func topDistraction(_ w: WeekStats) -> String? {
        w.byCategory.first { PauseCategory.byID[$0.id]?.weight.isDistraction == true }?.name
    }
}
