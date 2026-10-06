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
    var onboarded = false
    var theme: ThemePreset = .aurora
    var customPrimary = "#5B4BE0"
    var customAccent = "#16BBA9"
    var appearance: Appearance = .auto
    var orbStyle: OrbStyle = .blob
    /// Horario por día. La meta de cada día sale de aquí y se guarda en el día
    /// al crearlo, así un cambio de horario no altera los días anteriores.
    var schedule: WorkSchedule = .standard
    var use24h = true
    var haptics = true
    /// "¿Sigues en pausa?" pasados N minutos.
    var pauseReminder = true
    var pauseReminderMinutes = 30
    /// Aviso a la hora de inicio y de fin del horario.
    var remindStart = false
    var remindEnd = false
    /// Catálogo de categorías (el de la app más lo creado o editado).
    var categories: [PauseCategory] = PauseCategory.builtIn
    /// Categorías fijadas arriba en "¿Qué hacías?", en orden.
    var pinned: [String] = []

    init() {}

    /// Tolerante: si falta una clave (versión anterior), usa el valor por defecto
    /// en vez de perder todos los ajustes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        theme = (try? c.decodeIfPresent(ThemePreset.self, forKey: .theme)) ?? d.theme
        customPrimary = try c.decodeIfPresent(String.self, forKey: .customPrimary) ?? d.customPrimary
        customAccent = try c.decodeIfPresent(String.self, forKey: .customAccent) ?? d.customAccent
        appearance = (try? c.decodeIfPresent(Appearance.self, forKey: .appearance)) ?? d.appearance
        orbStyle = (try? c.decodeIfPresent(OrbStyle.self, forKey: .orbStyle)) ?? d.orbStyle
        schedule = (try? c.decodeIfPresent(WorkSchedule.self, forKey: .schedule)) ?? d.schedule
        use24h = try c.decodeIfPresent(Bool.self, forKey: .use24h) ?? d.use24h
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        pauseReminder = try c.decodeIfPresent(Bool.self, forKey: .pauseReminder) ?? d.pauseReminder
        pauseReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .pauseReminderMinutes) ?? d.pauseReminderMinutes
        remindStart = try c.decodeIfPresent(Bool.self, forKey: .remindStart) ?? d.remindStart
        remindEnd = try c.decodeIfPresent(Bool.self, forKey: .remindEnd) ?? d.remindEnd
        let saved = (try? c.decodeIfPresent([PauseCategory].self, forKey: .categories)) ?? d.categories
        categories = Catalog.merged(saved)
        pinned = try c.decodeIfPresent([String].self, forKey: .pinned) ?? d.pinned
    }
}

@MainActor
final class Preferences: ObservableObject {
    private static let key = "lapsus.settings"

    @Published var s: AppSettings {
        didSet {
            guard s != oldValue else { return }
            Haptics.enabled = s.haptics
            if s.categories != oldValue.categories {
                Catalog.set(s.categories)
            }
            if s.schedule != oldValue.schedule || s.remindStart != oldValue.remindStart || s.remindEnd != oldValue.remindEnd {
                Notifier.scheduleWorkReminders(s.schedule, start: s.remindStart, end: s.remindEnd, use24h: s.use24h)
            }
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
        Catalog.set(s.categories)
    }

    func palette(dark: Bool) -> Palette {
        Palette.make(preset: s.theme, customPrimary: s.customPrimary, customAccent: s.customAccent, dark: dark)
    }

    // MARK: Categorías

    func isPinned(_ id: String) -> Bool { s.pinned.contains(id) }

    func togglePin(_ id: String) {
        if let i = s.pinned.firstIndex(of: id) {
            s.pinned.remove(at: i)
        } else {
            s.pinned.append(id)
        }
    }

    /// Guarda una categoría nueva o editada.
    func upsert(_ cat: PauseCategory) {
        var list = s.categories
        if let i = list.firstIndex(where: { $0.id == cat.id }) {
            list[i] = cat
        } else {
            list.append(cat)
        }
        s.categories = list
    }

    /// Crea una categoría con solo el nombre (desde la búsqueda del modal).
    func quickCategory(named name: String) -> PauseCategory {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat = PauseCategory(id: "c-" + UUID().uuidString.prefix(8).lowercased(),
                                name: clean, short: clean, group: .other,
                                weight: .unclassified, icon: "star.fill", custom: true)
        upsert(cat)
        return cat
    }

    func setArchived(_ id: String, _ archived: Bool) {
        guard var cat = s.categories.first(where: { $0.id == id }) else { return }
        cat.archived = archived
        upsert(cat)
        if archived { s.pinned.removeAll { $0 == id } }
    }

    /// Borra del todo una categoría propia que nunca se usó.
    func deleteCategory(_ id: String) {
        s.categories.removeAll { $0.id == id }
        s.pinned.removeAll { $0 == id }
    }

    /// Vuelve las categorías de la app a su texto original; las propias se conservan.
    func resetBuiltInCategories() {
        let customs = s.categories.filter(\.custom)
        s.categories = PauseCategory.builtIn + customs
    }

    private func save() {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
