import SwiftUI

struct SettingsView: View {
    let settings: AppSettings
    let store: UsageStore

    var body: some View {
        TabView {
            ClaudeSettingsTab(settings: settings, store: store)
                .tabItem { Label("Claude", systemImage: "sparkle") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 380)
    }
}

private struct ClaudeSettingsTab: View {
    @Bindable var settings: AppSettings
    let store: UsageStore

    var body: some View {
        Form {
            Section {
                LimitField(
                    label: "Session (5h)",
                    valueInTokens: $settings.claudeSessionLimit,
                    currentUsed: currentUsed(named: "Session")
                )
                LimitField(
                    label: "Weekly · all models",
                    valueInTokens: $settings.claudeWeeklyAllLimit,
                    currentUsed: currentUsed(named: "Weekly")
                )
                LimitField(
                    label: "Weekly · Sonnet only",
                    valueInTokens: $settings.claudeWeeklySonnetLimit,
                    currentUsed: currentUsed(named: "Weekly · Sonnet")
                )
            } header: {
                Text("Claude plan limits")
            } footer: {
                Text("Values are in cost-weighted tokens (input + cache_create×1.25 + cache_read×0.1 + output×5). Calibrate by comparing to `/usage` inside Claude Code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Reset to defaults") {
                        settings.resetClaudeLimits()
                    }
                    Spacer()
                    Button("Refresh now") {
                        store.refresh()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func currentUsed(named title: String) -> Double? {
        store.summaries
            .first(where: { $0.provider == .claude })?
            .snapshots
            .first(where: { $0.title == title })?
            .used
    }
}

private struct LimitField: View {
    let label: String
    @Binding var valueInTokens: Double
    let currentUsed: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                Spacer()
                TextField("", value: millions, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                Text("M")
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .leading)
            }
            if let currentUsed {
                Text(usageHint(currentUsed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var millions: Binding<Double> {
        Binding(
            get: { valueInTokens / 1_000_000 },
            set: { valueInTokens = max(0, $0) * 1_000_000 }
        )
    }

    private func usageHint(_ used: Double) -> String {
        let pct = valueInTokens > 0 ? Int(((used / valueInTokens) * 100).rounded()) : 0
        let usedM = used / 1_000_000
        return String(format: "now: %.1fM tokens · %d%%", usedM, pct)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Tally")
                .font(.title.bold())
            Text("Local-first menu-bar tracker for AI token usage")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("v0.1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
