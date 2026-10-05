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

    static func cancelPauseReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pauseID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [pauseID])
    }
}
