import SwiftUI

/// "¿Qué hacías en esta pausa?" — aparece al tocar la ilustración en pausa.
/// No se puede saltar: hay que elegir al menos una opción para volver a trabajar.
struct ResumeSheet: View {
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    var pause: PauseEvent?
    var onDone: ([String], String) -> Void

    @State private var selected: [String] = []
    @State private var note = ""
    @State private var query = ""
    @FocusState private var noteFocused: Bool
    @FocusState private var searchFocused: Bool

    init(pause: PauseEvent?, onDone: @escaping ([String], String) -> Void) {
        self.pause = pause
        self.onDone = onDone
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Categorías que coinciden con lo escrito (sin importar tildes ni mayúsculas).
    private var matches: [PauseCategory] {
        let q = trimmedQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        guard !q.isEmpty else { return [] }
        let words = q.split(separator: " ").map(String.init)
        return PauseCategory.active.filter { c in
            let text = c.searchText
            return words.allSatisfy { text.contains($0) }
        }
    }

    private var pinnedCategories: [PauseCategory] {
        prefs.s.pinned.compactMap { id in PauseCategory.byID[id] }.filter { !$0.archived }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    searchField
                    if trimmedQuery.isEmpty {
                        pinnedSection
                        ForEach(PauseGroup.allCases) { group in
                            let cats = PauseCategory.inGroup(group)
                            if !cats.isEmpty {
                                section(title: group.name, color: group.color, cats: cats)
                            }
                        }
                    } else {
                        searchResults
                    }
                    noteField
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 16)
                .animation(.easeInOut(duration: 0.2), value: trimmedQuery.isEmpty)
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
        }
    }

    private func pauseText(_ now: Date) -> String {
        guard let pause else { return " " }
        return "Estuviste pausado \(Fmt.minutes(pause.duration(now: now))) · puedes marcar varias"
    }

    // MARK: Búsqueda

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pal.muted)
            TextField("Buscar: café, redes, reunión…", text: $query)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(pal.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit {
                    // Enter con un solo resultado: lo marca de una.
                    if matches.count == 1, let only = matches.first, !selected.contains(only.id) {
                        toggle(only.id)
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(pal.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(pal.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(searchFocused ? pal.primary : pal.border, lineWidth: searchFocused ? 1.5 : 1))
    }

    @ViewBuilder
    private var searchResults: some View {
        let found = matches
        VStack(alignment: .leading, spacing: 12) {
            if found.isEmpty {
                Text("No hay ninguna categoría con “\(trimmedQuery)”.")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(pal.sub)
            } else {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(found) { cat in chip(cat) }
                }
            }
            if !found.contains(where: { $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame }) {
                Button {
                    let cat = prefs.quickCategory(named: trimmedQuery)
                    toggle(cat.id)
                    query = ""
                } label: {
                    Label("Crear “\(trimmedQuery)” y marcarla", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(pal.primary)
                }
                .buttonStyle(.plain)
                Text("Queda en el grupo Otro; puedes editarla después en Ajustes → Categorías.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(pal.muted)
            }
        }
    }

    // MARK: Fijadas y grupos

    @ViewBuilder
    private var pinnedSection: some View {
        let pins = pinnedCategories
        if pins.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "pin")
                    .font(.system(size: 12, weight: .semibold))
                Text("Mantén presionada una opción para fijarla aquí arriba.")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(pal.muted)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(pal.primary)
                    Text("FIJADAS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(pal.primary)
                }
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(pins) { cat in chip(cat) }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pal.primarySoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func section(title: String, color: Color, cats: [PauseCategory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(pal.muted)
            }
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(cats) { cat in chip(cat) }
            }
        }
    }

    private func toggle(_ id: String) {
        if let i = selected.firstIndex(of: id) {
            selected.remove(at: i)
        } else {
            selected.append(id)
        }
        Haptics.tap()
    }

    private func chip(_ cat: PauseCategory) -> some View {
        let on = selected.contains(cat.id)
        let color = cat.group.color
        let pinned = prefs.isPinned(cat.id)
        return Button {
            toggle(cat.id)
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
        .contextMenu {
            Button {
                prefs.togglePin(cat.id)
                Haptics.success()
            } label: {
                Label(pinned ? "Quitar de fijadas" : "Fijar arriba", systemImage: pinned ? "pin.slash" : "pin")
            }
        }
    }

    // MARK: Nota y botón

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

    private var selectedNames: String {
        selected.compactMap { PauseCategory.byID[$0]?.short }.joined(separator: ", ")
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if !selected.isEmpty {
                Text(selectedNames)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(pal.sub)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            PrimaryButton(title: selected.isEmpty ? "Elige al menos una" : "Listo, seguir trabajando",
                          icon: selected.isEmpty ? nil : "play.fill",
                          gold: pause?.kind == .overtime,
                          enabled: !selected.isEmpty) {
                noteFocused = false
                searchFocused = false
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
