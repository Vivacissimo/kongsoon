import SwiftUI

struct EmotionHeaderCard: View {
    let analysis: DogEmotionAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(analysis.mode.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(analysis.currentState.title)
                        .font(.largeTitle.weight(.bold))

                    Text(analysis.currentState.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: analysis.currentState.iconName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(analysis.currentState.color)
                    .frame(width: 58, height: 58)
                    .background(analysis.currentState.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                MetricPill(title: "현재 행동", value: analysis.currentBehavior.title, icon: analysis.currentBehavior.iconName)
                MetricPill(title: "신뢰도", value: "\(Int(analysis.confidence * 100))%", icon: "checkmark.seal.fill")
            }

            Text(analysis.summaryText)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
        )
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
