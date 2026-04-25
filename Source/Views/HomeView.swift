import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actionCards
                infoCard
                disclaimerCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dog Emotion")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.blue)

                Spacer()
            }

            Text("강아지의 행동과 감정 상태를 분석합니다")
                .font(.largeTitle.weight(.bold))
                .lineSpacing(2)

            Text("실시간 카메라 또는 기존 영상을 통해 행동, 움직임, 오디오 이벤트를 기반으로 상태를 추정합니다.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var actionCards: some View {
        VStack(spacing: 16) {
            NavigationLink {
                RealtimeAnalysisView()
            } label: {
                PrimaryActionButton(title: "실시간 분석 시작", systemImage: "camera.viewfinder", tint: .blue)
            }
            .buttonStyle(.plain)

            NavigationLink {
                VideoAnalysisView()
            } label: {
                PrimaryActionButton(title: "기존 영상 분석", systemImage: "video.fill", tint: .purple)
            }
            .buttonStyle(.plain)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "분석 항목", icon: "waveform.path.ecg")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(icon: "figure.walk", title: "행동", detail: "걷기, 뛰기, 서성임, 식사")
                FeatureCard(icon: "face.smiling", title: "상태", detail: "편안함, 흥분, 불안/짜증")
                FeatureCard(icon: "speaker.wave.2.fill", title: "소리", detail: "짖음, 낑낑거림")
                FeatureCard(icon: "clock.fill", title: "타임라인", detail: "시간대별 변화")
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)

            Text("분석 결과는 영상과 소리 기반의 추정이며 수의학적 진단이 아닙니다. 이상 징후가 지속되면 수의사 또는 행동 전문가와 상담하세요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
