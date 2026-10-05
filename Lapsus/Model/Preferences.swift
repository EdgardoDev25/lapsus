import SwiftUI

enum OrbStyle: String, Codable, CaseIterable, Identifiable {
    case blob, waves, particles

    var id: String { rawValue }
    var name: String {
        switch self {
        case .blob: return "Blob"
        case .waves: return "Ondas"
        case .particles: return "Partículas"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var theme: ThemePreset = .aurora
    var customPrimary = "#5B4BE0"
    var customAccent = "#16BBA9"
    var appearance: Appearance = .auto
    var orbStyle: OrbStyle = .blob
    /// Meta diaria de la jornada normal.
    var goalMinutes = 480
    var use24h = true
    var haptics = true
    /// "¿Sigues en pausa?" pasados N minutos.
    var pauseReminder = true
    var pauseReminderMinutes = 30

    init() {}

    /// Tolerante: si falta una clave (versión anterior), usa el valor por defecto
    /// en vez de perder todos los ajustes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        theme = (try? c.decodeIfPresent(ThemePreset.self, forKey: .theme)) ?? d.theme
        customPrimary = try c.decodeIfPresent(String.self, forKey: .customPrimary) ?? d.customPrimary
        customAccent = try c.decodeIfPresent(String.self, forKey: .customAccent) ?? d.customAccent
        appearance = (try? c.decodeIfPresent(Appearance.self, forKey: .appearance)) ?? d.appearance
        orbStyle = (try? c.decodeIfPresent(OrbStyle.self, forKey: .orbStyle)) ?? d.orbStyle
        goalMinutes = try c.decodeIfPresent(Int.self, forKey: .goalMinutes) ?? d.goalMinutes
        use24h = try c.decodeIfPresent(Bool.self, forKey: .use24h) ?? d.use24h
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        pauseReminder = try c.decodeIfPresent(Bool.self, forKey: .pauseReminder) ?? d.pauseReminder
        pauseReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .pauseReminderMinutes) ?? d.pauseReminderMinutes
    }
}

@MainActor
final class Preferences: ObservableObject {
    private static let key = "lapsus.settings"

    @Published var s: AppSettings {
        didSet {
            guard s != oldValue else { return }
            Haptics.enabled = s.haptics
            save()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            s = loaded
        } else {
            s = AppSettings()
        }
        Haptics.enabled = s.haptics
    }

    func palette(dark: Bool) -> Palette {
        Palette.make(preset: s.theme, customPrimary: s.customPrimary, customAccent: s.customAccent, dark: dark)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
