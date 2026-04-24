import SwiftUI

struct AnalysisReportView: View {
    let analysis: DogEmotionAnalysis

    var body: some View {
        ScrollView {
            AnalysisReportContent(analysis: analysis)
                .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("분석 리포트")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AnalysisReportContent: View {
    let analysis: DogEmotionAnalysis

    var body: some View {
        VStack(spacing: 22) {
            EmotionHeaderCard(analysis: analysis)

            VStack(spacing: 22) {
                EmotionScoreBarList(scores: analysis.emotionScores)
                BehaviorScoreBarList(scores: analysis.behaviorScores)
                SignalListView(signals: analysis.signals)
                TimelineListView(timeline: analysis.timeline)
                safetyNote
            }
            .padding(20)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var safetyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("진단이 아닌 추정 결과")
                    .font(.subheadline.weight(.bold))
                Text("이 리포트는 영상/소리 기반 분석 보조 자료입니다. 통증, 질병, 심각한 불안 증상이 의심되면 전문가 상담이 필요합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        AnalysisReportView(analysis: MockDogEmotionAnalyzer.makeUploadedVideoResult())
    }
}
