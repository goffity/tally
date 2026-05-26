import SwiftUI

@main
struct TallyApp: App {
    @State private var store = UsageStore()
    @State private var scheduler: RefreshScheduler?

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
                .onAppear {
                    if scheduler == nil {
                        let s = RefreshScheduler(store: store, interval: 30)
                        s.start()
                        scheduler = s
                    }
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        Image(systemName: "chart.bar.fill")
    }
}
