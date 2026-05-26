import SwiftUI

struct ProviderSection: View {
    let summary: ProviderSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.provider.displayName.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            ForEach(summary.snapshots) { snapshot in
                UsageBarRow(snapshot: snapshot)
            }
        }
    }
}
