import SwiftUI

struct SignalListView: View {
    let signals: [AnalysisSignal]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "판단 근거", icon: "list.bullet.clipboard.fill")

            VStack(spacing: 12) {
                ForEach(signals) { signal in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(color(for: signal.weight))
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(signal.title)
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text(signal.weight.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(color(for: signal.weight))
                            }

                            Text(signal.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func color(for weight: SignalWeight) -> Color {
        switch weight {
        case .low:
            return .gray
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
