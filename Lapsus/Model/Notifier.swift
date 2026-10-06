import UserNotifications

/// Notificaciones locales. Todas son opcionales y se activan desde Ajustes.
enum Notifier {
    private static let pauseID = "lapsus.pause-reminder"

    /// Pide permiso la primera vez; si ya se decidió, no vuelve a preguntar.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// "¿Sigues en pausa?" pasados `minutes` minutos de la pausa.
    static func schedulePauseReminder(after minutes: Int) {
        guard minutes > 0 else { return }
        Task {
            guard await requestPermission() else { return }
            let content = UNMutableNotificationContent()
            content.title = "¿Sigues en pausa?"
            content.body = "Llevas \(minutes) min en pausa. Cuando vuelvas, toca la ilustración para seguir."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            let request = UNNotificationRequest(identifier: pauseID, content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Avisos semanales a la hora de inicio y fin del horario de cada día activo.
    /// Se reprograman completos cada vez que cambia el horario.
    static func scheduleWorkReminders(_ schedule: WorkSchedule, start: Bool, end: Bool, use24h: Bool) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<7).flatMap { ["lapsus.start-\($0)", "lapsus.end-\($0)"] }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard start || end else { return }
        Task {
            guard await requestPermission() else { return }
            for (i, plan) in schedule.days.enumerated() where plan.enabled && plan.minutes > 0 {
                // Calendario: 1 = domingo, 2 = lunes…
                let weekday = (i + 1) % 7 + 1
                if start {
                    let content = UNMutableNotificationContent()
                    content.title = "¿Empezamos?"
                    content.body = "Tu jornada inicia a las \(Fmt.clockTime(plan.start, use24h)). Toca la ilustración cuando arranques."
                    content.sound = .default
                    await add(center, id: "lapsus.start-\(i)", content: content, weekday: weekday, minutes: plan.start)
                }
                if end {
                    let content = UNMutableNotificationContent()
                    content.title = "¿Ya terminaste por hoy?"
                    content.body = "Tu horario termina a las \(Fmt.clockTime(plan.end, use24h)). Si ya acabaste, cierra el día en Lapsus."
                    content.sound = .default
                    await add(center, id: "lapsus.end-\(i)", content: content, weekday: weekday, minutes: plan.end)
                }
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, content: UNMutableNotificationContent,
                            weekday: Int, minutes: Int) async {
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancelPauseReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pauseID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [pauseID])
    }
}
