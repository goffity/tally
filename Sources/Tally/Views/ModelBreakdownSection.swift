import SwiftUI

/// "Weekly · by model" — informational per-model split of the trailing 7 days,
/// counted from local logs. Shares are relative to local usage on this machine,
/// not the official plan quota.
struct ModelBreakdownSection: View {
    let entries: [ClaudeUsageReader.ModelUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly · by model")
                .font(.headline)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(UsageBarRow.compactTokens(entry.tokens)) · \(percentLabel(entry.share))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ShareBar(value: entry.share)
                        .frame(height: 4)
                }
            }

            Text("estimate · counted from local logs")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func percentLabel(_ share: Double) -> String {
        let pct = share * 100
        if pct > 0, pct < 1 { return "<1%" }
        return "\(Int(pct.rounded()))%"
    }
}

private struct ShareBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: max(2, geo.size.width * min(max(value, 0), 1)))
            }
        }
    }
}
