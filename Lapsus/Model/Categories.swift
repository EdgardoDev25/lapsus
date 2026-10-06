import SwiftUI

/// Peso estadístico de una categoría. Lo usan las estadísticas para separar
/// descansos sanos de fugas de tiempo.
enum PauseWeight: String, Codable, CaseIterable, Identifiable {
    case positive, neutral, quasiProductive, mildDistraction, distraction, unclassified

    var id: String { rawValue }

    /// Cuenta como "distracción" en los insights.
    var isDistraction: Bool { self == .distraction || self == .mildDistraction }

    var name: String {
        switch self {
        case .positive: return "Descanso sano"
        case .neutral: return "Neutral"
        case .quasiProductive: return "Relacionado al trabajo"
        case .mildDistraction: return "Distracción leve"
        case .distraction: return "Distracción"
        case .unclassified: return "Sin clasificar"
        }
    }
}

enum PauseGroup: String, Codable, CaseIterable, Identifiable {
    case personal, healthy, social, errands, leisure, cognitive, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .personal: return "Necesidad personal"
        case .healthy: return "Descanso saludable"
        case .social: return "Social"
        case .errands: return "Diligencias"
        case .leisure: return "Ocio digital"
        case .cognitive: return "Relacionado al trabajo"
        case .other: return "Otro"
        }
    }

    var color: Color {
        switch self {
        case .personal: return Color(hex: 0x4A8FE0)
        case .healthy: return Color(hex: 0x12B5A8)
        case .social: return Color(hex: 0xD46BA3)
        case .errands: return Color(hex: 0x6F86A6)
        case .leisure: return Color(hex: 0xD99A2B)
        case .cognitive: return Color(hex: 0x7A66D6)
        case .other: return Color(hex: 0x9A97B4)
        }
    }

    /// Tipo sugerido al crear una categoría en este grupo.
    var defaultWeight: PauseWeight {
        switch self {
        case .healthy: return .positive
        case .leisure: return .distraction
        case .cognitive: return .quasiProductive
        case .other: return .unclassified
        default: return .neutral
        }
    }
}

struct PauseCategory: Identifiable, Hashable, Codable {
    var id: String
    /// Texto del chip.
    var name: String
    /// Texto corto para el historial ("Pausa 12 min · Merienda").
    var short: String
    var group: PauseGroup
    var weight: PauseWeight
    var icon: String
    /// Oculta del modal. No se borra para no perder el nombre en el historial.
    var archived = false
    /// Creada por la persona (no viene con la app).
    var custom = false

    init(id: String, name: String, short: String, group: PauseGroup, weight: PauseWeight, icon: String,
         archived: Bool = false, custom: Bool = false) {
        self.id = id
        self.name = name
        self.short = short
        self.group = group
        self.weight = weight
        self.icon = icon
        self.archived = archived
        self.custom = custom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        short = try c.decodeIfPresent(String.self, forKey: .short) ?? name
        group = (try? c.decodeIfPresent(PauseGroup.self, forKey: .group)) ?? .other
        weight = (try? c.decodeIfPresent(PauseWeight.self, forKey: .weight)) ?? group.defaultWeight
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "circle.fill"
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        custom = try c.decodeIfPresent(Bool.self, forKey: .custom) ?? false
    }

    /// Las que trae la app. Se pueden editar u ocultar desde Ajustes.
    static let builtIn: [PauseCategory] = [
        // Necesidad personal
        .init(id: "bano", name: "Baño", short: "Baño", group: .personal, weight: .neutral, icon: "drop.fill"),
        .init(id: "comer", name: "Merendando / comiendo", short: "Merienda", group: .personal, weight: .neutral, icon: "fork.knife"),
        .init(id: "bebida", name: "Agua o café", short: "Agua / café", group: .personal, weight: .neutral, icon: "cup.and.saucer.fill"),
        // Descanso saludable
        .init(id: "estirar", name: "Estirándome / moviéndome", short: "Estirarme", group: .healthy, weight: .positive, icon: "figure.walk"),
        .init(id: "break", name: "Break planificado", short: "Break", group: .healthy, weight: .positive, icon: "pause.circle.fill"),
        .init(id: "descanso", name: "Descansando / desconectando", short: "Descanso", group: .healthy, weight: .positive, icon: "moon.zzz.fill"),
        .init(id: "meditar", name: "Meditando / respirando", short: "Meditar", group: .healthy, weight: .positive, icon: "wind"),
        // Social
        .init(id: "conversar", name: "Conversando en persona", short: "Conversar", group: .social, weight: .neutral, icon: "bubble.left.and.bubble.right.fill"),
        .init(id: "llamada", name: "Llamada o mensaje personal", short: "Llamada personal", group: .social, weight: .neutral, icon: "phone.fill"),
        .init(id: "favor", name: "Haciendo un favor", short: "Un favor", group: .social, weight: .neutral, icon: "hand.raised.fill"),
        .init(id: "interrupcion", name: "Me interrumpieron", short: "Interrupción", group: .social, weight: .neutral, icon: "person.fill.questionmark"),
        // Diligencias
        .init(id: "tramite", name: "Diligencia / mandado", short: "Diligencia", group: .errands, weight: .neutral, icon: "bag.fill"),
        .init(id: "archivos", name: "Organizando archivos", short: "Archivos", group: .errands, weight: .neutral, icon: "folder.fill"),
        .init(id: "espacio", name: "Organizando algo físico", short: "Organizar", group: .errands, weight: .neutral, icon: "shippingbox.fill"),
        // Ocio digital
        .init(id: "redes", name: "Redes sociales / memes", short: "Redes", group: .leisure, weight: .distraction, icon: "iphone"),
        .init(id: "juego", name: "Videojuego", short: "Videojuego", group: .leisure, weight: .distraction, icon: "gamecontroller.fill"),
        .init(id: "musica", name: "Poniendo música o podcast", short: "Música", group: .leisure, weight: .mildDistraction, icon: "music.note"),
        .init(id: "navegar", name: "Navegando sin rumbo", short: "Navegar", group: .leisure, weight: .distraction, icon: "safari.fill"),
        // Relacionado al trabajo
        .init(id: "pensar", name: "Pensando en el trabajo", short: "Pensar", group: .cognitive, weight: .quasiProductive, icon: "lightbulb.fill"),
        .init(id: "investigar", name: "Consultando / investigando", short: "Investigar", group: .cognitive, weight: .quasiProductive, icon: "magnifyingglass"),
        .init(id: "correo", name: "Correo o mensajes de trabajo", short: "Correo", group: .cognitive, weight: .quasiProductive, icon: "envelope.fill"),
        .init(id: "reunion", name: "Reunión o llamada de trabajo", short: "Reunión", group: .cognitive, weight: .quasiProductive, icon: "person.2.fill"),
        // Otro
        .init(id: "distraccion", name: "Distracción", short: "Distracción", group: .other, weight: .distraction, icon: "tornado"),
        .init(id: "otro", name: "Otro (detállalo en la nota)", short: "Otro", group: .other, weight: .unclassified, icon: "ellipsis.circle.fill"),
    ]

    /// Íconos para elegir al crear o editar una categoría.
    static let iconChoices: [String] = [
        "drop.fill", "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "pills.fill", "bed.double.fill",
        "figure.walk", "figure.run", "dumbbell.fill", "moon.zzz.fill", "wind", "leaf.fill",
        "sun.max.fill", "pause.circle.fill", "bubble.left.and.bubble.right.fill", "phone.fill", "message.fill", "person.2.fill",
        "hand.raised.fill", "person.fill.questionmark", "figure.and.child.holdinghands", "pawprint.fill", "heart.fill", "house.fill",
        "bag.fill", "cart.fill", "car.fill", "creditcard.fill", "folder.fill", "shippingbox.fill",
        "iphone", "tv.fill", "gamecontroller.fill", "music.note", "headphones", "safari.fill",
        "play.rectangle.fill", "book.fill", "newspaper.fill", "lightbulb.fill", "magnifyingglass", "envelope.fill",
        "calendar", "doc.text.fill", "pencil", "hammer.fill", "wrench.and.screwdriver.fill", "graduationcap.fill",
        "tornado", "flame.fill", "bolt.fill", "star.fill", "ellipsis.circle.fill", "questionmark.circle.fill",
    ]

    /// Texto sin tildes ni mayúsculas, para la búsqueda.
    var searchText: String {
        "\(name) \(short) \(group.name)".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
    }
}

/// Catálogo en uso (el de la app más lo que la persona creó o editó).
/// Lo mantiene al día `Preferences`; aquí queda a mano para modelos y estadísticas.
enum Catalog {
    private(set) static var items: [PauseCategory] = PauseCategory.builtIn
    private(set) static var index: [String: PauseCategory] = Dictionary(uniqueKeysWithValues: PauseCategory.builtIn.map { ($0.id, $0) })

    static func set(_ list: [PauseCategory]) {
        items = list
        index = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Agrega al final las categorías de la app que falten en una lista guardada
    /// (por ejemplo, si una versión nueva trae categorías nuevas).
    static func merged(_ saved: [PauseCategory]) -> [PauseCategory] {
        var list = saved
        let ids = Set(saved.map(\.id))
        for c in PauseCategory.builtIn where !ids.contains(c.id) {
            list.append(c)
        }
        return list
    }
}

extension PauseCategory {
    static var all: [PauseCategory] { Catalog.items }
    static var byID: [String: PauseCategory] { Catalog.index }
    /// Las que aparecen en el modal.
    static var active: [PauseCategory] { Catalog.items.filter { !$0.archived } }

    static func inGroup(_ g: PauseGroup) -> [PauseCategory] {
        active.filter { $0.group == g }
    }
}
