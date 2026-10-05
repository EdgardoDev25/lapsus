import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var store: WorkStore
    @Environment(\.palette) private var pal

    @State private var confirmDelete = false

    private let presets: [ThemePreset] = [.aurora, .medianoche, .atardecer, .bosque, .minimal]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle(title: "Ajustes")

                SectionLabel("Tema de color").padding(.top, 22).padding(.bottom, 12)
                themes
                customColor.padding(.top, 12)

                SectionLabel("Apariencia").padding(.top, 22).padding(.bottom, 12)
                appearance

                SectionLabel("Estilo de ilustración").padding(.top, 22).padding(.bottom, 12)
                orbStyles

                SectionLabel("Preferencias").padding(.top, 22).padding(.bottom, 12)
                preferences

                SectionLabel("Tus datos").padding(.top, 22).padding(.bottom, 12)
                dataSection

                about.padding(.top, 28)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(pal.bg.ignoresSafeArea())
        .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { store.deleteAll() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminan todos los días, pausas y tareas registrados. No se puede deshacer.")
        }
    }

    // MARK: Tema

    private var themes: some View {
        HStack(spacing: 10) {
            ForEach(presets) { t in
                let on = prefs.s.theme == t
                Button {
                    prefs.s.theme = t
                    Haptics.tap()
                } label: {
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: Palette.swatch(t, customPrimary: prefs.s.customPrimary, customAccent: prefs.s.customAccent),
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 50)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(pal.bg, lineWidth: on ? 3 : 0)
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(on ? pal.primary : Color.clear, lineWidth: 2)
                                    .padding(-2)
                            }
                        Text(t.name)
                            .font(.system(size: 10.5, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? pal.primary : pal.sub)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private var customColor: some View {
        let on = prefs.s.theme == .personalizado
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Color personalizado")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.text)
                Text(on ? "En uso" : "Toca un color para usarlo")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(on ? pal.primary : pal.muted)
            }
            Spacer()
            ColorPicker("Principal", selection: colorBinding(\.customPrimary, fallback: 0x5B4BE0), supportsOpacity: false)
                .labelsHidden()
            ColorPicker("Acento", selection: colorBinding(\.customAccent, fallback: 0x16BBA9), supportsOpacity: false)
                .labelsHidden()
        }
        .card(padding: 14, radius: 15)
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(on ? pal.primary : Color.clear, lineWidth: 2)
        }
    }

    private func colorBinding(_ key: WritableKeyPath<AppSettings, String>, fallback: UInt32) -> Binding<Color> {
        Binding(
            get: { Color(hexString: prefs.s[keyPath: key]) ?? Color(hex: fallback) },
            set: { newValue in
                prefs.s[keyPath: key] = newValue.hexString
                prefs.s.theme = .personalizado
            }
        )
    }

    // MARK: Apariencia

    private var appearance: some View {
        HStack(spacing: 0) {
            ForEach(Appearance.allCases) { a in
                let on = prefs.s.appearance == a
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { prefs.s.appearance = a }
                    Haptics.tap()
                } label: {
                    Text(a.name)
                        .font(.system(size: 13.5, weight: on ? .bold : .semibold))
                        .foregroundStyle(on ? pal.primary : pal.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(pal.card)
                                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(pal.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Ilustración

    private var orbStyles: some View {
        HStack(spacing: 10) {
            ForEach(OrbStyle.allCases) { style in
                let on = prefs.s.orbStyle == style
                Button {
                    prefs.s.orbStyle = style
                    Haptics.tap()
                } label: {
                    VStack(spacing: 6) {
                        FocusOrb(style: style, mood: on ? .running : .idle, palette: pal)
                            .frame(width: 64, height: 64)
                        Text(style.name)
                            .font(.system(size: 11.5, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? pal.primary : pal.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(pal.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(on ? pal.primary : pal.border, lineWidth: on ? 2 : 1)
                    }
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    // MARK: Preferencias

    private var preferences: some View {
        VStack(spacing: 0) {
            stepperRow("Meta diaria", value: Fmt.hm(Double(prefs.s.goalMinutes) * 60),
                       minus: prefs.s.goalMinutes > 60, plus: prefs.s.goalMinutes < 720) { delta in
                prefs.s.goalMinutes = min(720, max(60, prefs.s.goalMinutes + delta * 30))
                store.updateGoal(prefs.s.goalMinutes)
            }
            divider
            toggleRow("Formato 24 horas", isOn: binding(\.use24h))
            divider
            toggleRow("Vibración", isOn: binding(\.haptics))
            divider
            toggleRow("Recordarme si sigo en pausa", isOn: binding(\.pauseReminder))
            if prefs.s.pauseReminder {
                divider
                stepperRow("Avisar a los", value: "\(prefs.s.pauseReminderMinutes) min",
                           minus: prefs.s.pauseReminderMinutes > 5, plus: prefs.s.pauseReminderMinutes < 120) { delta in
                    prefs.s.pauseReminderMinutes = min(120, max(5, prefs.s.pauseReminderMinutes + delta * 5))
                }
            }
        }
        .background(pal.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
        .onChange(of: prefs.s.pauseReminder) { _, on in
            if on { Task { _ = await Notifier.requestPermission() } }
        }
    }

    private var divider: some View {
        Rectangle().fill(pal.divider).frame(height: 1).padding(.leading, 16)
    }

    private func binding(_ key: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { prefs.s[keyPath: key] }, set: { prefs.s[keyPath: key] = $0 })
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.text)
        }
        .tint(pal.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func stepperRow(_ title: String, value: String, minus: Bool, plus: Bool, change: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.text)
            Spacer()
            stepButton("minus", enabled: minus) { change(-1) }
            Text(value)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(pal.primary)
                .frame(minWidth: 62)
            stepButton("plus", enabled: plus) { change(1) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tick()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(pal.primary)
                .frame(width: 30, height: 30)
                .background(pal.primarySoft, in: Circle())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    // MARK: Datos

    private var dataSection: some View {
        VStack(spacing: 10) {
            ShareLink(item: CSVExport(days: store.days, use24h: prefs.s.use24h),
                      preview: SharePreview("Registros de Lapsus")) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                    Text("Exportar CSV")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(pal.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(pal.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
            }
            Button {
                confirmDelete = true
            } label: {
                Text("Borrar todos los datos")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(pal.bad)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Acerca de

    private var about: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        let date = info?["LPBuildDate"] as? String ?? ""
        return VStack(spacing: 4) {
            Text("Lapsus \(version) (\(build))")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(pal.sub)
            Text("Desarrollado y diseñado por Edgardo Rocha")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(pal.muted)
            if !date.isEmpty && date != "local" {
                Text("Compilado \(date)")
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(pal.faint)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
