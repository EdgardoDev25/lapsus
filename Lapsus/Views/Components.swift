import SwiftUI

/// Tarjeta blanca con borde suave y sombra, como en el diseño.
struct CardStyle: ViewModifier {
    @Environment(\.palette) private var pal
    var padding: CGFloat = 18
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pal.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
            .shadow(color: Color(hex: 0x1E1846).opacity(pal.isDark ? 0 : 0.06), radius: 13, x: 0, y: 10)
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }
}

/// "DÍAS RECIENTES", "TEMA DE COLOR"…
struct SectionLabel: View {
    @Environment(\.palette) private var pal
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11.5, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(pal.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Título grande de cada pestaña.
struct ScreenTitle: View {
    @Environment(\.palette) private var pal
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(pal.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(pal.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Botón grande de acción (Listo, Guardar, Iniciar horas extra…).
struct PrimaryButton: View {
    @Environment(\.palette) private var pal
    var title: String
    var icon: String?
    var gold = false
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gold ? AnyShapeStyle(pal.goldGradient) : AnyShapeStyle(pal.primary))
            }
            .shadow(color: (gold ? pal.gold : pal.primary).opacity(enabled ? 0.28 : 0), radius: 14, x: 0, y: 8)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

/// Botón secundario con borde.
struct SecondaryButton: View {
    @Environment(\.palette) private var pal
    var title: String
    var icon: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(pal.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(pal.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// Se encoge un poco al presionar.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Distribuye chips en filas que se parten solas.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxW {
                y += lineH + lineSpacing
                x = 0
                lineH = 0
            }
            widest = max(widest, x + s.width)
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX {
                y += lineH + lineSpacing
                x = bounds.minX
                lineH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}

/// Anillo de progreso (focus ratio, meta).
struct Ring: View {
    @Environment(\.palette) private var pal
    var value: Double
    var lineWidth: CGFloat = 9
    var color: Color?

    var body: some View {
        ZStack {
            Circle().stroke(pal.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(color ?? pal.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Barra horizontal de progreso.
struct ProgressBar: View {
    @Environment(\.palette) private var pal
    var value: Double
    var height: CGFloat = 7
    var fill: AnyShapeStyle?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(pal.track)
                Capsule()
                    .fill(fill ?? AnyShapeStyle(LinearGradient(colors: [pal.gradA, pal.primary], startPoint: .leading, endPoint: .trailing)))
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: height)
    }
}

/// Punto + línea vertical de la línea de tiempo del día.
struct TimelineRow: View {
    @Environment(\.palette) private var pal
    @EnvironmentObject private var prefs: Preferences
    var item: TimelineItem
    var isLast: Bool
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(dotColor).frame(width: 9, height: 9).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: compact ? 13 : 13.5, weight: .semibold))
                    .foregroundStyle(pal.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .regular).italic())
                        .foregroundStyle(pal.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(Fmt.time(item.date, prefs.s.use24h))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(pal.muted)
            }
            .padding(.bottom, isLast ? 0 : (compact ? 10 : 14))
            Spacer(minLength: 0)
        }
        // La línea que une un punto con el siguiente ocupa todo el alto de la fila.
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle().fill(pal.divider).frame(width: 2)
                    .padding(.top, 16)
                    .padding(.leading, 3.5)
            }
        }
    }

    private var dotColor: Color {
        switch item.kind {
        case .start: return Color(hex: 0x12B5A8)
        case .resume: return pal.faint
        case .pause:
            if let c = item.category, let cat = PauseCategory.byID[c] { return cat.group.color }
            return pal.muted
        case .end: return pal.primary
        case .overtimeStart, .overtimeEnd: return pal.gold
        }
    }
}

/// Lista completa de eventos de un día.
struct DayTimeline: View {
    var items: [TimelineItem]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                TimelineRow(item: item, isLast: i == items.count - 1, compact: compact)
            }
        }
    }
}
