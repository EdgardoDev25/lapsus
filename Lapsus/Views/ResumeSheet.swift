import SwiftUI

/// "¿Qué hacías en esta pausa?" — aparece al tocar la ilustración en pausa.
/// No se puede saltar: hay que elegir al menos una opción para volver a trabajar.
struct ResumeSheet: View {
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    var pause: PauseEvent?
    var onDone: ([String], String) -> Void

    @State private var selected: [String] = []
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    init(pause: PauseEvent?, onDone: @escaping ([String], String) -> Void) {
        self.pause = pause
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    ForEach(PauseGroup.allCases) { group in
                        groupSection(group)
                    }
                    noteField
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(pal.bg.ignoresSafeArea())
        .interactiveDismissDisabled(true)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("¿Qué hacías en esta pausa?")
                .font(.system(size: 25, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(pal.ink)
                .fixedSize(horizontal: false, vertical: true)
            TimelineView(.periodic(from: .now, by: 10)) { tl in
                Text(pauseText(tl.date))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(pal.sub)
            }
            Text("Puedes marcar varias.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(pal.muted)
        }
    }

    private func pauseText(_ now: Date) -> String {
        guard let pause else { return " " }
        return "Estuviste pausado \(Fmt.minutes(pause.duration(now: now)))"
    }

    private func groupSection(_ group: PauseGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 3).fill(group.color).frame(width: 10, height: 10)
                Text(group.name.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(pal.muted)
            }
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(PauseCategory.inGroup(group)) { cat in
                    chip(cat)
                }
            }
        }
    }

    private func chip(_ cat: PauseCategory) -> some View {
        let on = selected.contains(cat.id)
        let color = cat.group.color
        return Button {
            if let i = selected.firstIndex(of: cat.id) {
                selected.remove(at: i)
            } else {
                selected.append(cat.id)
            }
            Haptics.tap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: cat.icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(on ? .white : color)
                Text(cat.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(on ? .white : pal.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? color : pal.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? color : pal.border, lineWidth: 1)
            }
        }
        .buttonStyle(PressStyle())
        .animation(.easeOut(duration: 0.15), value: on)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTA (OPCIONAL)")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(pal.muted)
            TextField("Ej. me llamó el contador", text: $note)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(pal.ink)
                .focused($noteFocused)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(pal.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: selected.isEmpty ? "Elige al menos una" : "Listo, seguir trabajando",
                          icon: selected.isEmpty ? nil : "play.fill",
                          gold: pause?.kind == .overtime,
                          enabled: !selected.isEmpty) {
                noteFocused = false
                onDone(selected, note)
                dismiss()
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(pal.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(pal.border).frame(height: 1)
        }
    }
}
