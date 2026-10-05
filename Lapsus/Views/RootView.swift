import Combine
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var prefs: Preferences

    var body: some View {
        ThemedRoot()
            .preferredColorScheme(prefs.s.appearance.scheme)
    }
}

/// Lee el modo claro/oscuro ya aplicado y reparte la paleta a toda la app.
private struct ThemedRoot: View {
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var store: WorkStore
    @Environment(\.colorScheme) private var scheme
    @State private var tab = 0

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let pal = prefs.palette(dark: scheme == .dark)
        TabView(selection: $tab) {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(0)
            HistoryView()
                .tabItem { Label("Historial", systemImage: "calendar") }
                .tag(1)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
                .tag(3)
        }
        .tint(pal.primary)
        .environment(\.palette, pal)
        .onChange(of: tab) { _, _ in Haptics.tick() }
        // Cruce de medianoche con la app abierta.
        .onReceive(minuteTimer) { _ in store.rollover() }
    }
}
