import Foundation

/// Fechas y duraciones en español, sin depender del idioma del iPhone.
enum Fmt {
    /// Calendario con la semana empezando el lunes.
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        c.locale = Locale(identifier: "es_CO")
        c.timeZone = .current
        return c
    }()

    static let months = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
                         "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    static let monthsShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    /// Índice 1 = domingo (como `Calendar.component(.weekday)`).
    static let weekdays = ["", "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    static let weekdaysShort = ["", "Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
    /// Iniciales de lunes a domingo.
    static let weekInitials = ["L", "M", "X", "J", "V", "S", "D"]

    static func dayID(_ date: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Duraciones

    /// "01:23:45"
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// "6h 20m", "45m", "0m"
    static func hm(_ seconds: TimeInterval) -> String {
        let m = max(0, Int(seconds)) / 60
        if m >= 60 { return "\(m / 60)h \(String(format: "%02d", m % 60))m" }
        return "\(m)m"
    }

    /// "12 min", "1 h 05 min", "menos de 1 min"
    static func minutes(_ seconds: TimeInterval) -> String {
        let m = max(0, Int(seconds.rounded())) / 60
        if m < 1 { return "<1 min" }
        if m >= 60 { return "\(m / 60) h \(String(format: "%02d", m % 60)) min" }
        return "\(m) min"
    }

    /// Horas con un decimal: "6.2 h"
    static func hoursDecimal(_ seconds: TimeInterval) -> String {
        String(format: "%.1f h", seconds / 3600)
    }

    static func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }

    // MARK: Fechas

    /// "08:32" o "8:32 pm"
    static func time(_ date: Date, _ use24h: Bool) -> String {
        let c = cal.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0
        if use24h { return String(format: "%02d:%02d", h, m) }
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, h < 12 ? "am" : "pm")
    }

    /// "Viernes 4 jul"
    static func dayTitle(_ date: Date) -> String {
        let c = cal.dateComponents([.weekday, .day, .month], from: date)
        return "\(weekdays[c.weekday ?? 1]) \(c.day ?? 0) \(monthsShort[(c.month ?? 1) - 1])"
    }

    /// "Domingo, 5 de octubre"
    static func dayLong(_ date: Date) -> String {
        let c = cal.dateComponents([.weekday, .day, .month], from: date)
        return "\(weekdays[c.weekday ?? 1]), \(c.day ?? 0) de \(months[(c.month ?? 1) - 1])"
    }

    /// "4 jul"
    static func dayShort(_ date: Date) -> String {
        let c = cal.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 0) \(monthsShort[(c.month ?? 1) - 1])"
    }

    /// "Jue"
    static func weekdayShort(_ date: Date) -> String {
        weekdaysShort[cal.component(.weekday, from: date)]
    }

    /// "Octubre 2026"
    static func monthTitle(_ date: Date) -> String {
        let c = cal.dateComponents([.year, .month], from: date)
        return "\(months[(c.month ?? 1) - 1].capitalized) \(c.year ?? 0)"
    }

    /// "Semana del 30 jun — 6 jul"
    static func weekTitle(_ start: Date) -> String {
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        return "Semana del \(dayShort(start)) — \(dayShort(end))"
    }
}
