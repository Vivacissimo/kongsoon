import PhotosUI
import SwiftUI

struct VideoAnalysisView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedMovie: Movie?
    @State private var isAnalyzing = false
    @State private var progress = 0.0
    @State private var analysis: DogEmotionAnalysis?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                pickerCard

                if isAnalyzing {
                    analyzingCard
                }

                if let errorMessage {
                    errorCard(message: errorMessage)
                }

                if let analysis {
                    AnalysisReportContent(analysis: analysis)
                } else if !isAnalyzing {
                    emptyStateCard
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("기존 영상 분석")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                await loadAndAnalyze(item: newItem)
            }
        }
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("영상 선택")
                        .font(.title2.weight(.bold))
                    Text("사진 앱에 저장된 강아지 영상을 선택하면 감정/행동 리포트를 생성합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "film.stack.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.purple)
            }

            PhotosPicker(selection: $selectedItem, matching: .videos) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedMovie == nil ? "영상 가져오기" : "다른 영상 선택")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if let selectedMovie {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(selectedMovie.url.lastPathComponent)
                        .font(.footnote)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var analyzingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ProgressView()
                Text("영상 분석 중")
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(.purple)

            Text("프레임 샘플링, 행동 패턴 추정, 감정 상태 계산을 진행 중입니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.badge.waveform")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("아직 분석한 영상이 없습니다")
                .font(.headline)

            Text("영상을 선택하면 이 영역에 감정 비율, 행동 비율, 시간대별 타임라인이 표시됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func errorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color.red.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @MainActor
    private func loadAndAnalyze(item: PhotosPickerItem?) async {
        guard let item else { return }

        isAnalyzing = true
        progress = 0
        errorMessage = nil
        analysis = nil

        do {
            selectedMovie = try await item.loadTransferable(type: Movie.self)

            guard let selectedMovie else {
                throw AnalyzerError.invalidAssetDuration
            }

            analysis = try await VisionDogEmotionAnalyzer.analyzeVideo(at: selectedMovie.url) { currentProgress in
                progress = currentProgress
            }
        } catch {
            errorMessage = "영상 로드 또는 분석 준비 중 오류가 발생했습니다: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }
}
