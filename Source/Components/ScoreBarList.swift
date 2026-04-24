import SwiftUI

struct EmotionScoreBarList: View {
    let scores: [EmotionScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "감정 상태 비율", icon: "chart.bar.fill")

            VStack(spacing: 12) {
                ForEach(scores) { score in
                    ScoreBarRow(
                        title: score.state.title,
                        ratio: score.ratio,
                        color: score.state.color
                    )
                }
            }
        }
    }
}

struct BehaviorScoreBarList: View {
    let scores: [BehaviorScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "행동 패턴 비율", icon: "pawprint.fill")

            VStack(spacing: 12) {
                ForEach(scores) { score in
                    ScoreBarRow(
                        title: score.behavior.title,
                        ratio: score.ratio,
                        color: .blue
                    )
                }
            }
        }
    }
}

struct ScoreBarRow: View {
    let title: String
    let ratio: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))

                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(8, geometry.size.width * ratio))
                }
            }
            .frame(height: 10)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}
