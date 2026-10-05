import SwiftUI

@main
struct LapsusApp: App {
    @StateObject private var prefs: Preferences
    @StateObject private var store: WorkStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let prefs = Preferences()
        _prefs = StateObject(wrappedValue: prefs)
        _store = StateObject(wrappedValue: WorkStore(prefs: prefs))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prefs)
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                store.saveNow()
            case .active:
                // Si pasó la medianoche con el día cerrado, abre el día nuevo.
                store.rollover()
            default:
                break
            }
        }
    }
}
