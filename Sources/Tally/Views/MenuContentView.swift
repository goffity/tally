import SwiftUI
import AppKit

struct MenuContentView: View {
    let store: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            if store.summaries.isEmpty {
                emptyState
            } else {
                ForEach(store.summaries) { summary in
                    ProviderSection(summary: summary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text("TALLY")
                .font(.headline.weight(.heavy))
                .tracking(1.2)
            Spacer()
            Text(updatedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var updatedLabel: String {
        guard let last = store.lastUpdated else { return "—" }
        let delta = Int(-last.timeIntervalSinceNow)
        if delta < 60 { return "updated \(max(delta, 0))s ago" }
        if delta < 3600 { return "updated \(delta / 60)m ago" }
        return "updated \(delta / 3600)h ago"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No usage data yet")
                .font(.headline)
            Text("Start a Claude Code session to see numbers here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            menuRow(systemImage: "gearshape", title: "Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            menuRow(systemImage: "power", title: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private func menuRow(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
