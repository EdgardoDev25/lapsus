import SwiftUI

/// Ajustes → Categorías de pausa: crear, editar, fijar y ocultar.
struct CategoriesSheet: View {
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var store: WorkStore
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    private struct EditRequest: Identifiable {
        let id = UUID()
        let category: PauseCategory
        let isNew: Bool
    }

    @State private var editing: EditRequest?
    @State private var confirmReset = false

    init() {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Toca una categoría para editarla. Desliza a la derecha para fijarla arriba en “¿Qué hacías?”, o a la izquierda para ocultarla.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(pal.sub)
                        .listRowBackground(Color.clear)
                }

                ForEach(PauseGroup.allCases) { g in
                    let cats = prefs.s.categories.filter { $0.group == g && !$0.archived }
                    if !cats.isEmpty {
                        Section {
                            ForEach(cats) { c in row(c) }
                        } header: {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3).fill(g.color).frame(width: 9, height: 9)
                                Text(g.name)
                            }
                        }
                    }
                }

                let hidden = prefs.s.categories.filter(\.archived)
                if !hidden.isEmpty {
                    Section {
                        ForEach(hidden) { c in
                            Button {
                                prefs.setArchived(c.id, false)
                                Haptics.tap()
                            } label: {
                                HStack(spacing: 12) {
                                    icon(c).opacity(0.5)
                                    Text(c.name)
                                        .foregroundStyle(pal.sub)
                                    Spacer()
                                    Text("Mostrar")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(pal.primary)
                                }
                            }
                        }
                    } header: {
                        Text("Ocultas")
                    } footer: {
                        Text("Las ocultas no salen en el modal, pero tus pausas pasadas las conservan.")
                    }
                }

                Section {
                    Button("Restablecer las categorías originales") { confirmReset = true }
                        .foregroundStyle(pal.bad)
                } footer: {
                    Text("Devuelve nombre, grupo e ícono de las que trae la app. Las que creaste se conservan.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(pal.bg.ignoresSafeArea())
            .navigationTitle("Categorías de pausa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(pal.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let blank = PauseCategory(id: "c-" + UUID().uuidString.prefix(8).lowercased(),
                                                  name: "", short: "", group: .other,
                                                  weight: PauseGroup.other.defaultWeight, icon: "star.fill", custom: true)
                        editing = EditRequest(category: blank, isNew: true)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nueva categoría")
                }
            }
            .sheet(item: $editing) { req in
                CategoryEditor(category: req.category, isNew: req.isNew,
                               used: store.isCategoryUsed(req.category.id),
                               pinned: prefs.isPinned(req.category.id))
                    .environmentObject(prefs)
                    .environment(\.palette, pal)
            }
            .confirmationDialog("¿Restablecer las categorías originales?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Restablecer", role: .destructive) { prefs.resetBuiltInCategories() }
                Button("Cancelar", role: .cancel) {}
            }
        }
        .tint(pal.primary)
    }

    private func icon(_ c: PauseCategory) -> some View {
        Image(systemName: c.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(c.group.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func row(_ c: PauseCategory) -> some View {
        let pinned = prefs.isPinned(c.id)
        return Button {
            editing = EditRequest(category: c, isNew: false)
        } label: {
            HStack(spacing: 12) {
                icon(c)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(pal.ink)
                    Text(c.custom ? "\(c.weight.name) · propia" : c.weight.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(pal.muted)
                }
                Spacer()
                if pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(pal.primary)
                }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                prefs.togglePin(c.id)
                Haptics.tap()
            } label: {
                Label(pinned ? "Desfijar" : "Fijar", systemImage: pinned ? "pin.slash" : "pin")
            }
            .tint(pal.primary)
        }
        .swipeActions(edge: .trailing) {
            Button {
                prefs.setArchived(c.id, true)
                Haptics.tap()
            } label: {
                Label("Ocultar", systemImage: "eye.slash")
            }
            .tint(.gray)
        }
    }
}

/// Crear o editar una categoría.
struct CategoryEditor: View {
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    /// Ya hay pausas con esta categoría: se puede ocultar, no borrar.
    let used: Bool
    private let originalName: String

    @State private var cat: PauseCategory
    @State private var pinned: Bool

    init(category: PauseCategory, isNew: Bool, used: Bool, pinned: Bool) {
        self.isNew = isNew
        self.used = used
        self.originalName = category.name
        _cat = State(initialValue: category)
        _pinned = State(initialValue: pinned)
    }

    private var trimmedName: String { cat.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        preview
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Nombre") {
                    TextField("Ej. Pasear al perro", text: $cat.name)
                        .font(.system(size: 16, weight: .medium))
                }

                Section {
                    Picker("Grupo", selection: $cat.group) {
                        ForEach(PauseGroup.allCases) { g in
                            Text(g.name).tag(g)
                        }
                    }
                    Picker("Tipo", selection: $cat.weight) {
                        ForEach(PauseWeight.allCases) { w in
                            Text(w.name).tag(w)
                        }
                    }
                } footer: {
                    Text("El tipo decide cómo cuenta en tus estadísticas: un descanso sano no es lo mismo que una distracción.")
                }

                Section("Ícono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                        ForEach(PauseCategory.iconChoices, id: \.self) { name in
                            let on = cat.icon == name
                            Button {
                                cat.icon = name
                                Haptics.tick()
                            } label: {
                                Image(systemName: name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(on ? .white : pal.text)
                                    .frame(width: 40, height: 40)
                                    .background(on ? cat.group.color : pal.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Toggle("Fijar arriba en “¿Qué hacías?”", isOn: $pinned)
                        .tint(pal.primary)
                }

                if !isNew {
                    Section {
                        if cat.custom && !used {
                            Button("Eliminar categoría", role: .destructive) {
                                prefs.deleteCategory(cat.id)
                                dismiss()
                            }
                        } else {
                            Button("Ocultar categoría", role: .destructive) {
                                prefs.setArchived(cat.id, true)
                                dismiss()
                            }
                        }
                    } footer: {
                        if used || !cat.custom {
                            Text("Se oculta del modal; las pausas que ya la usan la conservan.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(pal.bg.ignoresSafeArea())
            .navigationTitle(isNew ? "Nueva categoría" : "Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.bold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onChange(of: cat.group) { _, g in
                if isNew { cat.weight = g.defaultWeight }
            }
        }
        .tint(pal.primary)
    }

    private var preview: some View {
        HStack(spacing: 7) {
            Image(systemName: cat.icon)
                .font(.system(size: 13, weight: .semibold))
            Text(trimmedName.isEmpty ? "Nueva categoría" : trimmedName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(cat.group.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func save() {
        var c = cat
        c.name = trimmedName
        // El texto corto del historial sigue al nombre si este cambió.
        if isNew || c.name != originalName { c.short = c.name }
        prefs.upsert(c)
        if pinned != prefs.isPinned(c.id) { prefs.togglePin(c.id) }
        Haptics.success()
        dismiss()
    }
}
