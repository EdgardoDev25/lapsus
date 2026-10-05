import SwiftUI

/// Cierre de la jornada (o de las horas extra): "¿Trabajaste hoy?", resumen y tareas realizadas.
struct FinishSheet: View {
    @EnvironmentObject private var store: WorkStore
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    let request: FinishRequest

    private struct Draft: Identifiable {
        let id = UUID()
        var text = ""
    }

    @State private var askedWork = false
    @State private var drafts: [Draft] = [Draft()]
    @FocusState private var focused: UUID?

    init(request: FinishRequest) {
        self.request = request
    }

    private var overtime: Bool { request.kind == .overtime }
    private var day: WorkDay { store.current }

    var body: some View {
        NavigationStack {
            Group {
                if overtime || askedWork {
                    summary
                } else {
                    workedQuestion
                }
            }
            .background(pal.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(pal.sub)
                }
            }
            .toolbarBackground(pal.bg, for: .navigationBar)
        }
        .presentationCornerRadius(30)
    }

    // MARK: Paso 1

    private var workedQuestion: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 46))
                .foregroundStyle(pal.gradient)
            Text("¿Trabajaste hoy?")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(pal.ink)
                .padding(.top, 18)
            Text("Si abriste la app por error o no fue un día de trabajo, el día queda guardado pero fuera de tus estadísticas.")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(pal.sub)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 12)
            Spacer()
            VStack(spacing: 10) {
                PrimaryButton(title: "Sí, cerrar mi jornada", icon: "checkmark") {
                    withAnimation(.easeInOut(duration: 0.25)) { askedWork = true }
                }
                SecondaryButton(title: "No, hoy no trabajé") {
                    store.finish(at: request.at, didWork: false, tasks: [])
                    dismiss()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Paso 2

    private var summary: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(overtime ? "Cierre de horas extra" : "Resumen de tu día")
                            .font(.system(size: 26, weight: .heavy))
                            .tracking(-0.5)
                            .foregroundStyle(pal.ink)
                        Text("Hasta las \(Fmt.time(request.at, prefs.s.use24h))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(pal.sub)
                    }
                    metrics
                    tasksEditor
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(title: overtime ? "Guardar horas extra" : "Guardar y cerrar el día",
                          icon: "checkmark", gold: overtime) {
                store.finish(at: request.at, didWork: true, tasks: drafts.map(\.text))
                dismiss()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
    }

    private var metrics: some View {
        let kind = request.kind
        let f = day.focused(kind, now: request.at)
        let p = day.paused(kind, now: request.at)
        let ratio = f + p > 0 ? f / (f + p) : 0
        let pauses = day.pauses.filter { $0.kind == kind && $0.end != nil }.count
        return HStack(spacing: 14) {
            ZStack {
                Ring(value: ratio, lineWidth: 9, color: overtime ? pal.gold : pal.primary)
                VStack(spacing: 0) {
                    Text(Fmt.percent(ratio))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(pal.ink)
                    Text("focus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(pal.muted)
                }
            }
            .frame(width: 78, height: 78)
            VStack(alignment: .leading, spacing: 6) {
                row("Enfocado", Fmt.hm(f))
                row("En pausa", Fmt.hm(p))
                row("Pausas", "\(pauses)")
            }
        }
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(pal.sub)
            Spacer()
            Text(value)
                .font(.system(size: 14.5, weight: .bold).monospacedDigit())
                .foregroundStyle(pal.ink)
        }
    }

    private var tasksEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(overtime ? "Qué hiciste en las horas extra" : "Tareas realizadas hoy")
            ForEach($drafts) { $draft in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(draft.text.isEmpty ? pal.faint : (overtime ? pal.gold : pal.primary))
                    TextField("Ej. cerré el reporte", text: $draft.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(pal.ink)
                        .focused($focused, equals: draft.id)
                        .submitLabel(.next)
                        .onSubmit { addDraft() }
                    if drafts.count > 1 {
                        Button {
                            drafts.removeAll { $0.id == draft.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(pal.faint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(pal.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
            }
            Button {
                addDraft()
            } label: {
                Label("Agregar tarea", systemImage: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(overtime ? pal.goldDeep : pal.primary)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            Text("Opcional. Una por línea.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(pal.muted)
        }
    }

    private func addDraft() {
        if let last = drafts.last, last.text.trimmingCharacters(in: .whitespaces).isEmpty {
            focused = last.id
            return
        }
        let d = Draft()
        drafts.append(d)
        focused = d.id
    }
}
