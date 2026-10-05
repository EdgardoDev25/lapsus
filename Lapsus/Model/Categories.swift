import SwiftUI

/// Peso estadístico de una categoría. El usuario no lo ve; lo usan las estadísticas
/// para separar descansos sanos de fugas de tiempo.
enum PauseWeight: String {
    case neutral, positive, distraction, mildDistraction, quasiProductive, unclassified

    /// Cuenta como "distracción" en los insights.
    var isDistraction: Bool { self == .distraction || self == .mildDistraction }
}

enum PauseGroup: String, CaseIterable, Identifiable {
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
}

struct PauseCategory: Identifiable, Hashable {
    let id: String
    /// Texto del chip.
    let name: String
    /// Texto corto para el historial ("Pausa 12 min · Merienda").
    let short: String
    let group: PauseGroup
    let weight: PauseWeight
    let icon: String

    static let all: [PauseCategory] = [
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

    static let byID: [String: PauseCategory] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func inGroup(_ g: PauseGroup) -> [PauseCategory] {
        all.filter { $0.group == g }
    }
}
