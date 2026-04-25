import AVFoundation
import SwiftUI
import Combine

struct RealtimeAnalysisView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var analysis = MockDogEmotionAnalyzer.makeRealtimeResult()
    @State private var isAnalysisSessionActive = false
    @State private var isAnalyzingRecordedVideo = false
    @State private var recordedVideoAnalysisError: String?
    @State private var sessionStartDate: Date?
    @State private var elapsedSeconds = 0
    @State private var showRecordedReport = false

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            cameraLayer
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                topStatusBar
                resultPanel
            }
            .padding(16)
        }
        .background(.black)
        .navigationTitle("녹화 분석")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.black.opacity(0.55), for: .navigationBar)
        .onAppear {
            cameraManager.requestPermissionAndConfigure()
        }
        .onDisappear {
            cameraManager.stopRecording()
            cameraManager.stop()
        }
        .onReceive(timer) { _ in
            guard isAnalysisSessionActive else { return }
            updateElapsedTime()
            analysis = MockDogEmotionAnalyzer.makeRealtimeResult()
        }
        .onChange(of: cameraManager.lastRecordedVideoURL) { _, newURL in
            guard let newURL else { return }

            Task {
                await analyzeRecordedVideo(url: newURL)
            }
        }
        .navigationDestination(isPresented: $showRecordedReport) {
            AnalysisReportView(analysis: analysis)
        }
    }

    @ViewBuilder
    private var cameraLayer: some View {
        switch cameraManager.authorizationStatus {
        case .authorized:
            CameraPreview(session: cameraManager.session)
                .overlay(alignment: .center) {
                    DogDetectionFrameView(state: analysis.currentState)
                        .padding(34)
                        .opacity(isAnalysisSessionActive ? 1.0 : 0.45)
                }
        case .notDetermined:
            PermissionMessageView(
                icon: "camera.fill",
                title: "카메라 권한 확인 중",
                detail: "녹화 분석을 위해 카메라 권한을 요청합니다."
            )
        case .denied, .restricted:
            PermissionMessageView(
                icon: "lock.fill",
                title: "카메라 권한 필요",
                detail: cameraManager.errorMessage ?? "설정에서 카메라 접근을 허용해주세요."
            )
        @unknown default:
            PermissionMessageView(
                icon: "exclamationmark.triangle.fill",
                title: "카메라 오류",
                detail: "카메라 상태를 확인할 수 없습니다."
            )
        }
    }

    private var topStatusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.weight(.bold))

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button {
                toggleRecordingSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isAnalysisSessionActive ? "stop.fill" : "record.circle")
                    Text(isAnalysisSessionActive ? "정지" : "시작")
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(isAnalysisSessionActive ? Color.red.opacity(0.95) : Color.white.opacity(0.92))
                .foregroundStyle(isAnalysisSessionActive ? .white : .red)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var resultPanel: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isAnalysisSessionActive ? "녹화 중 추정 상태" : "분석 대기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: analysis.currentState.iconName)
                            .foregroundStyle(analysis.currentState.color)

                        Text(isAnalysisSessionActive ? analysis.currentState.title : "시작 버튼을 눌러 녹화")
                            .font(.title2.weight(.bold))
                    }

                    Text(resultDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(isAnalysisSessionActive ? "\(Int(analysis.confidence * 100))%" : formatElapsedTime(elapsedSeconds))
                        .font(.title3.weight(.bold))
                    Text(isAnalysisSessionActive ? "신뢰도" : "녹화 길이")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Divider()

            SignalListView(signals: Array(analysis.signals.prefix(2)))
                .opacity(isAnalysisSessionActive ? 1.0 : 0.6)

            if isAnalyzingRecordedVideo {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("녹화 영상을 분석 중입니다…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let recordedVideoAnalysisError {
                Text(recordedVideoAnalysisError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if cameraManager.lastRecordedVideoURL != nil && !isAnalysisSessionActive {
                Button {
                    showRecordedReport = true
                } label: {
                    Text("녹화 영상 리포트 보기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(analysis.currentState.color.opacity(0.14))
                        .foregroundStyle(analysis.currentState.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("특정 행동을 분석하려면 시작을 누르고 행동 구간을 녹화한 뒤 정지하세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var statusColor: Color {
        if isAnalysisSessionActive {
            return .red
        }

        if cameraManager.lastRecordedVideoURL != nil {
            return .green
        }

        return .gray
    }

    private var statusTitle: String {
        if isAnalysisSessionActive {
            return "녹화 및 분석 중"
        }

        if cameraManager.lastRecordedVideoURL != nil {
            return "녹화 완료"
        }

        return "대기 중"
    }

    private var statusSubtitle: String {
        if isAnalysisSessionActive {
            return "경과 시간 \(formatElapsedTime(elapsedSeconds))"
        }

        if cameraManager.lastRecordedVideoURL != nil {
            return isAnalyzingRecordedVideo ? "녹화가 끝나 분석을 수행하는 중입니다." : "저장된 영상으로 리포트를 확인할 수 있습니다."
        }

        return "특정 행동이 시작될 때 녹화를 시작하세요."
    }

    private var resultDescription: String {
        if isAnalysisSessionActive {
            return analysis.summaryText
        }

        if cameraManager.lastRecordedVideoURL != nil {
            return isAnalyzingRecordedVideo
                ? "Core ML 모델 기반 영상 분석을 수행하는 중입니다."
                : "녹화가 끝났습니다. 분석 리포트를 확인하세요."
        }

        return "실시간으로 계속 분석하기보다, 분석하고 싶은 행동 구간만 녹화해서 리포트로 보는 흐름입니다."
    }

    private func toggleRecordingSession() {
        if isAnalysisSessionActive {
            isAnalysisSessionActive = false
            cameraManager.stopRecording()
        } else {
            elapsedSeconds = 0
            sessionStartDate = Date()
            cameraManager.startRecording()
            isAnalysisSessionActive = true
            recordedVideoAnalysisError = nil
            analysis = MockDogEmotionAnalyzer.makeRealtimeResult()
        }
    }

    @MainActor
    private func analyzeRecordedVideo(url: URL) async {
        isAnalyzingRecordedVideo = true
        recordedVideoAnalysisError = nil

        do {
            analysis = try await VisionDogEmotionAnalyzer.analyzeVideo(at: url)
        } catch {
            analysis = MockDogEmotionAnalyzer.makeUploadedVideoResult()
            recordedVideoAnalysisError = "실제 분석에 실패해 Mock 리포트로 대체했습니다: \(error.localizedDescription)"
        }

        isAnalyzingRecordedVideo = false
    }

    private func updateElapsedTime() {
        guard let sessionStartDate else { return }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(sessionStartDate)))
    }

    private func formatElapsedTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct DogDetectionFrameView: View {
    let state: EmotionState

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(state.color, lineWidth: 4)
            .frame(maxWidth: .infinity, maxHeight: 360)
            .overlay(alignment: .topLeading) {
                Text("Dog · \(state.title)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(state.color)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(12)
            }
    }
}

struct PermissionMessageView: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
