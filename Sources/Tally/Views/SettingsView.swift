import AppKit
import SwiftUI

struct SettingsView: View {
    let settings: AppSettings
    let store: UsageStore

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ClaudeSettingsTab(settings: settings, store: store)
                .tabItem { Label("Claude", systemImage: "sparkle") }
            GeminiSettingsTab(settings: settings, store: store)
                .tabItem { Label("Gemini", systemImage: "diamond") }
            CopilotSettingsTab(settings: settings, store: store)
                .tabItem { Label("Copilot", systemImage: "person.fill") }
            RelaySettingsTab(settings: settings, store: store)
                .tabItem { Label("Relay", systemImage: "antenna.radiowaves.left.and.right") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 420)
    }
}

private struct GeneralSettingsTab: View {
    @State private var launchAtLogin = LaunchAtLoginService.isEnabled
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Launch Tally at login",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            let result = LaunchAtLoginService.setEnabled(newValue)
                            switch result {
                            case .success:
                                launchAtLogin = LaunchAtLoginService.isEnabled
                                errorMessage = nil
                                statusMessage = LaunchAtLoginService.statusDescription
                            case .failure(let error):
                                launchAtLogin = LaunchAtLoginService.isEnabled
                                errorMessage = error.localizedDescription
                            }
                        }
                    ))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text(
                    "Tally needs to be in /Applications for launch-at-login to work reliably. First-time toggle may prompt for approval in System Settings → General → Login Items."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
                Text(
                    "Values are in cost-weighted tokens (input + cache_create×1.25 + cache_read×0.1 + output×5). Calibrate by comparing to `/usage` inside Claude Code."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: $settings.officialPollInterval, in: 180...3600, step: 30) {
                    HStack {
                        Text("Official poll interval")
                        Spacer()
                        Text("\(Int(settings.officialPollInterval))s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Official /usage endpoint")
            } footer: {
                Text(
                    "How often Tally queries Anthropic's official usage endpoint. Minimum 180s — polling faster risks rate-limiting your access token. On 429 or error, Tally backs off and falls back to local logs automatically."
                )
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

private struct GeminiSettingsTab: View {
    @Bindable var settings: AppSettings
    let store: UsageStore

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Text("Daily requests")
                    Spacer()
                    TextField(
                        "", value: $settings.geminiDailyRequests,
                        format: .number.precision(.fractionLength(0))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                    Text("req")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)
                }
                if let current = currentUsed {
                    let pct =
                        settings.geminiDailyRequests > 0
                        ? Int(((current / settings.geminiDailyRequests) * 100).rounded())
                        : 0
                    Text(String(format: "today: %d requests · %d%%", Int(current), pct))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Gemini plan limits")
            } footer: {
                Text(
                    "Gemini CLI doesn't record token counts locally — Tally counts user messages in the last 24 hours as a proxy for requests. Free tier is documented at ~1000 req/day; bump this number if you're on a paid plan."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var currentUsed: Double? {
        store.summaries
            .first(where: { $0.provider == .gemini })?
            .snapshots
            .first?
            .used
    }
}

private struct CopilotSettingsTab: View {
    @Bindable var settings: AppSettings
    let store: UsageStore

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Text("Monthly premium requests")
                    Spacer()
                    TextField(
                        "", value: $settings.copilotMonthlyPremiumRequests,
                        format: .number.precision(.fractionLength(0))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                    Text("req")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)
                }
                if let current = currentUsed {
                    let pct =
                        settings.copilotMonthlyPremiumRequests > 0
                        ? Int(((current / settings.copilotMonthlyPremiumRequests) * 100).rounded())
                        : 0
                    Text(String(format: "this month: %d requests · %d%%", Int(current), pct))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Copilot plan limits")
            } footer: {
                Text(
                    "Tally counts `totalPremiumRequests` from each Copilot session's shutdown event. Default 300 matches Copilot Pro; bump to 1500 for Pro+, or your plan's actual cap. In-flight sessions are not counted until they end."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var currentUsed: Double? {
        store.summaries
            .first(where: { $0.provider == .copilot })?
            .snapshots
            .first?
            .used
    }
}

private struct RelaySettingsTab: View {
    @Bindable var settings: AppSettings
    let store: UsageStore

    var body: some View {
        Form {
            Section {
                Toggle("Publish usage to relay", isOn: $settings.relayPublishEnabled)
            } header: {
                Text("Outbound publishing")
            } footer: {
                Text(
                    "Off by default. Tally is local-first — when this is off, nothing leaves your Mac. Turn it on to push usage to your relay so the iPhone StandBy widget can read it. Only numbers (percentages + reset times) are sent — never your tokens."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                TextField("https://your-worker.workers.dev", text: $settings.relayEndpointURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                SecureField("relay token", text: $settings.relayToken)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Relay connection")
            } footer: {
                Text(
                    "The token is stored in your Keychain — never in preferences or logs. It must match the RELAY_TOKEN secret on your relay Worker. The widget reads from \(settings.relayEndpointURL.isEmpty ? "<endpoint>/usage" : "\(settings.relayEndpointURL)/usage")."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Label(sourceText, systemImage: sourceIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh now") { store.refresh() }
                }
                if settings.relayPublishEnabled, let status = store.relayStatus {
                    Text(status)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(
                    "Source of the latest Claude reading. \"official\" matches `/usage` exactly; \"local\" is an estimate from session logs and the widget shows it as approximate."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var claudeSource: UsageStore.Source? { store.sources[.claude] }

    private var sourceText: String {
        switch claudeSource {
        case .api: return "Source: official"
        case .localFallback(let reason): return "Source: local — \(reason)"
        case .localOnly: return "Source: local"
        case nil: return "Source: —"
        }
    }

    private var sourceIcon: String {
        switch claudeSource {
        case .api: return "checkmark.seal"
        case .localFallback, .localOnly: return "wave.3.right"
        case nil: return "questionmark.circle"
        }
    }
}

private struct LimitField: View {
    let label: String
    @Binding var valueInTokens: Double
    let currentUsed: Double?

    @State private var showCalibrate = false

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
                Button {
                    showCalibrate = true
                } label: {
                    Image(systemName: "scope")
                }
                .buttonStyle(.borderless)
                .help("Calibrate from /usage")
                .disabled((currentUsed ?? 0) <= 0)
            }
            if let currentUsed {
                Text(usageHint(currentUsed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .popover(isPresented: $showCalibrate, arrowEdge: .trailing) {
            CalibrationPopover(
                label: label,
                currentUsed: currentUsed ?? 0,
                onCalibrate: { percent in
                    let used = currentUsed ?? 0
                    guard percent > 0, used > 0 else { return }
                    valueInTokens = used / (percent / 100.0)
                }
            )
        }
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

private struct CalibrationPopover: View {
    let label: String
    let currentUsed: Double
    let onCalibrate: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var percentString: String = ""

    private var parsedPercent: Double? {
        guard let v = Double(percentString), v > 0, v <= 100 else { return nil }
        return v
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibrate \(label)")
                .font(.headline)
            Text(
                "Open `/usage` in Claude Code and enter the percent it reports for this window. Tally will back-calculate the limit from your current usage of \(format(currentUsed))."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("e.g. 7", text: $percentString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text("%")
                    .foregroundStyle(.secondary)
            }

            if let p = parsedPercent {
                let implied = currentUsed / (p / 100.0)
                Text(String(format: "Implied limit: %.1fM tokens", implied / 1_000_000))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Calibrate") {
                    if let p = parsedPercent {
                        onCalibrate(p)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsedPercent == nil)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1fM tokens", value / 1_000_000)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
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
