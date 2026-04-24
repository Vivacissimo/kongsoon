import AVFoundation
import SwiftUI
import Combine

struct RealtimeAnalysisView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var analysis = MockDogEmotionAnalyzer.makeRealtimeResult()
    @State private var isAnalyzing = true

    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

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
        .navigationTitle("실시간 분석")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.black.opacity(0.55), for: .navigationBar)
        .onAppear {
            cameraManager.requestPermissionAndConfigure()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .onReceive(timer) { _ in
            guard isAnalyzing else { return }
            analysis = MockDogEmotionAnalyzer.makeRealtimeResult()
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
                }
        case .notDetermined:
            PermissionMessageView(
                icon: "camera.fill",
                title: "카메라 권한 확인 중",
                detail: "실시간 분석을 위해 카메라 권한을 요청합니다."
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
                .fill(isAnalyzing ? .green : .gray)
                .frame(width: 10, height: 10)

            Text(isAnalyzing ? "분석 중" : "일시정지")
                .font(.subheadline.weight(.bold))

            Spacer()

            Button {
                isAnalyzing.toggle()
            } label: {
                Image(systemName: isAnalyzing ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(width: 38, height: 38)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var resultPanel: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("현재 추정 상태")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: analysis.currentState.iconName)
                            .foregroundStyle(analysis.currentState.color)

                        Text(analysis.currentState.title)
                            .font(.title2.weight(.bold))
                    }

                    Text(analysis.summaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("\(Int(analysis.confidence * 100))%")
                        .font(.title3.weight(.bold))
                    Text("신뢰도")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Divider()

            SignalListView(signals: Array(analysis.signals.prefix(2)))

            NavigationLink {
                AnalysisReportView(analysis: analysis)
            } label: {
                Text("상세 리포트 보기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(analysis.currentState.color.opacity(0.14))
                    .foregroundStyle(analysis.currentState.color)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
