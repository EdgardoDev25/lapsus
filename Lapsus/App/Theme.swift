import SwiftUI
import UIKit

extension Color {
    /// Color desde 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Color desde "#RRGGBB" (o "RRGGBB"). Si no se puede leer, devuelve nil.
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }

    /// "#RRGGBB" de un color cualquiera (para guardar el color personalizado).
    var hexString: String {
        let c = RGBA(self)
        let r = Int((c.r * 255).rounded()), g = Int((c.g * 255).rounded()), b = Int((c.b * 255).rounded())
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

/// Componentes de un color, para mezclar colores cuadro a cuadro en la ilustración.
struct RGBA: Equatable {
    var r: Double, g: Double, b: Double, a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    func mix(_ o: RGBA, _ t: Double) -> RGBA {
        RGBA(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t, a: a + (o.a - a) * t)
    }

    /// Versión apagada (para el estado en pausa).
    func desaturated(_ amount: Double) -> RGBA {
        let gray = r * 0.3 + g * 0.59 + b * 0.11
        return mix(RGBA(r: gray, g: gray, b: gray, a: a), amount)
    }

    func with(alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }
}

enum ThemePreset: String, Codable, CaseIterable, Identifiable {
    case aurora, medianoche, atardecer, bosque, minimal, personalizado

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aurora: return "Aurora"
        case .medianoche: return "Medianoche"
        case .atardecer: return "Atardecer"
        case .bosque: return "Bosque"
        case .minimal: return "Minimal"
        case .personalizado: return "Propio"
        }
    }
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case claro, oscuro, auto

    var id: String { rawValue }
    var name: String {
        switch self {
        case .claro: return "Claro"
        case .oscuro: return "Oscuro"
        case .auto: return "Auto"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .claro: return .light
        case .oscuro: return .dark
        case .auto: return nil
        }
    }
}

/// Colores de la app según tema y modo claro/oscuro.
struct Palette {
    var isDark: Bool

    // Tema
    var primary: Color
    var gradA: Color
    var gradB: Color
    /// Fondo suave del color del tema (insights, chips seleccionados).
    var primarySoft: Color

    // Neutros
    var bg: Color
    var card: Color
    var border: Color
    var divider: Color
    var track: Color
    var ink: Color
    var text: Color
    var sub: Color
    var muted: Color
    var faint: Color

    // Horas extra (dorado / ámbar)
    var gold: Color
    var goldDeep: Color
    var goldSoft: Color
    var goldBorder: Color

    var good: Color
    var bad: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [gradA, gradB], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xF0B64A), Color(hex: 0xD9862B)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func make(preset: ThemePreset, customPrimary: String, customAccent: String, dark: Bool) -> Palette {
        let (p, a, b) = colors(preset: preset, customPrimary: customPrimary, customAccent: customAccent, dark: dark)
        return Palette(
            isDark: dark,
            primary: p, gradA: a, gradB: b,
            primarySoft: p.opacity(dark ? 0.18 : 0.10),
            bg: dark ? Color(hex: 0x0F0E17) : Color(hex: 0xF4F3FB),
            card: dark ? Color(hex: 0x1A1826) : .white,
            border: dark ? Color(hex: 0x2A2740) : Color(hex: 0xECEAF6),
            divider: dark ? Color(hex: 0x24223A) : Color(hex: 0xEEECF7),
            track: dark ? Color(hex: 0x26233A) : Color(hex: 0xEEEBF7),
            ink: dark ? Color(hex: 0xF1F0FA) : Color(hex: 0x26233F),
            text: dark ? Color(hex: 0xD6D4E6) : Color(hex: 0x3A3752),
            sub: dark ? Color(hex: 0xA19EBB) : Color(hex: 0x8380A0),
            muted: dark ? Color(hex: 0x86839F) : Color(hex: 0x9A97B4),
            faint: dark ? Color(hex: 0x5E5B78) : Color(hex: 0xB4B1CB),
            gold: Color(hex: 0xD99A2B),
            goldDeep: dark ? Color(hex: 0xEDB04A) : Color(hex: 0xA9741E),
            goldSoft: dark ? Color(hex: 0x2A2216) : Color(hex: 0xFBF3E6),
            goldBorder: dark ? Color(hex: 0x4A3A1E) : Color(hex: 0xF1E2C5),
            good: Color(hex: 0x1F9A62),
            bad: Color(hex: 0xE0653F)
        )
    }

    private static func colors(preset: ThemePreset, customPrimary: String, customAccent: String, dark: Bool) -> (Color, Color, Color) {
        switch preset {
        case .aurora:
            return (dark ? Color(hex: 0x8B7CF6) : Color(hex: 0x5B4BE0), Color(hex: 0x6A57E8), Color(hex: 0x16BBA9))
        case .medianoche:
            return (dark ? Color(hex: 0x7F86F0) : Color(hex: 0x3D4AA8), Color(hex: 0x1E3A6E), Color(hex: 0x5C5FD0))
        case .atardecer:
            return (dark ? Color(hex: 0xF08A78) : Color(hex: 0xD2557A), Color(hex: 0xF0805E), Color(hex: 0xC24BA0))
        case .bosque:
            return (dark ? Color(hex: 0x4CC594) : Color(hex: 0x1C8A60), Color(hex: 0x1F9E6E), Color(hex: 0x7C9A3E))
        case .minimal:
            return (dark ? Color(hex: 0xDCDCE4) : Color(hex: 0x33333B), Color(hex: 0x4A4A55), Color(hex: 0x9A9AA6))
        case .personalizado:
            let p = Color(hexString: customPrimary) ?? Color(hex: 0x5B4BE0)
            let a = Color(hexString: customAccent) ?? Color(hex: 0x16BBA9)
            return (p, p, a)
        }
    }

    /// Los dos colores del degradado de un tema, para las muestras de Ajustes.
    static func swatch(_ preset: ThemePreset, customPrimary: String, customAccent: String) -> [Color] {
        let (_, a, b) = colors(preset: preset, customPrimary: customPrimary, customAccent: customAccent, dark: false)
        return [a, b]
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(preset: .aurora, customPrimary: "", customAccent: "", dark: false)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
