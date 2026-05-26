import SwiftUI

struct UsageBarRow: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(percentLabel)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(barColor)
            }

            ProgressBar(value: snapshot.percent, color: barColor)
                .frame(height: 6)

            Text(usageLine)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(footerLine)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if snapshot.isEstimate {
                Text("estimate · counted from local logs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var percentLabel: String {
        "\(Int((snapshot.percent * 100).rounded()))%"
    }

    private var barColor: Color {
        switch snapshot.percent {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }

    private var footerLine: String {
        "\(snapshot.subtitle) · \(resetPhrase)"
    }

    private var usageLine: String {
        let unit = snapshot.unit == .requests ? "requests" : "tokens"
        return "\(format(snapshot.used)) / \(format(snapshot.limit)) \(unit)"
    }

    private func format(_ value: Double) -> String {
        if snapshot.unit == .requests {
            return Self.intFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }
        return Self.compactTokens(value)
    }

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static func compactTokens(_ value: Double) -> String {
        let abs = Swift.abs(value)
        switch abs {
        case 0..<1_000:
            return String(Int(value.rounded()))
        case 1_000..<10_000:
            return String(format: "%.1fk", value / 1_000)
        case 10_000..<1_000_000:
            return String(format: "%.0fk", value / 1_000)
        case 1_000_000..<10_000_000:
            return String(format: "%.2fM", value / 1_000_000)
        default:
            return String(format: "%.1fM", value / 1_000_000)
        }
    }

    private var resetPhrase: String {
        let interval = snapshot.resetsAt.timeIntervalSinceNow
        if interval <= 0 { return "resetting…" }
        let oneDay: TimeInterval = 24 * 3600
        if interval < oneDay {
            let h = Int(interval) / 3600
            let m = (Int(interval) % 3600) / 60
            if h > 0 { return "resets in \(h)h \(m)m" }
            return "resets in \(m)m"
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return "resets \(fmt.string(from: snapshot.resetsAt))"
    }
}

private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                Capsule()
                    .fill(color)
                    .frame(width: max(2, geo.size.width * min(max(value, 0), 1)))
            }
        }
    }
}
