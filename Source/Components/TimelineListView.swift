import SwiftUI

struct TimelineListView: View {
    let timeline: [BehaviorSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "시간대별 분석", icon: "timeline.selection")

            VStack(spacing: 0) {
                ForEach(timeline) { segment in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(segment.emotion.color)
                                .frame(width: 12, height: 12)

                            Rectangle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 2)
                        }
                        .frame(height: 66)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(segment.timeRangeText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack {
                                Text(segment.behavior.title)
                                    .font(.subheadline.weight(.bold))

                                Text("·")
                                    .foregroundStyle(.secondary)

                                Text(segment.emotion.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(segment.emotion.color)

                                Spacer()

                                Text("\(Int(segment.confidence * 100))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
