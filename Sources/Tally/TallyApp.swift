import SwiftUI

@main
struct TallyApp: App {
    @State private var settings = AppSettings()
    @State private var store: UsageStore
    @State private var scheduler: RefreshScheduler?

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _store = State(initialValue: UsageStore(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
                .onAppear {
                    if scheduler == nil {
                        let s = RefreshScheduler(store: store)
                        s.start()
                        scheduler = s
                    }
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, store: store)
        }
    }

    private var menuBarLabel: some View {
        Image(systemName: "chart.bar.fill")
    }
}
