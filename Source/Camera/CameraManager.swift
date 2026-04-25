@preconcurrency import AVFoundation
import Foundation
import Combine

final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()

    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isConfigured = false
    @Published var isRecording = false
    @Published var lastRecordedVideoURL: URL?
    @Published var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "kongsoon.camera.session.queue")
    private var didConfigureSession = false
    private let movieOutput = AVCaptureMovieFileOutput()

    private var recordingDelegate: MovieRecordingDelegate?

    func requestPermissionAndConfigure() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)

        DispatchQueue.main.async {
            self.authorizationStatus = currentStatus
        }

        switch currentStatus {
        case .authorized:
            configureSessionIfNeeded()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }

                if granted {
                    self.configureSessionIfNeeded()
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "카메라 권한이 필요합니다."
                    }
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "카메라 권한이 필요합니다. 설정에서 카메라 접근을 허용해주세요."
            }

        @unknown default:
            DispatchQueue.main.async {
                self.errorMessage = "알 수 없는 카메라 권한 상태입니다."
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.didConfigureSession {
                self.configureSession()
            }

            if self.didConfigureSession && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        stopRecording()

        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.didConfigureSession {
                self.configureSession()
            }

            guard self.didConfigureSession else {
                DispatchQueue.main.async {
                    self.errorMessage = "카메라 세션이 아직 준비되지 않았습니다."
                }
                return
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            if self.movieOutput.isRecording {
                return
            }

            let fileURL = CameraManager.makeTemporaryMovieURL()

            let delegate = MovieRecordingDelegate(
                didStart: { [weak self] in
                    DispatchQueue.main.async {
                        self?.isRecording = true
                        self?.errorMessage = nil
                    }
                },
                didFinish: { [weak self] outputURL, error in
                    DispatchQueue.main.async {
                        guard let self else { return }

                        self.isRecording = false

                        if let error {
                            self.errorMessage = "녹화 저장 실패: \(error.localizedDescription)"
                            self.recordingDelegate = nil
                            return
                        }

                        self.lastRecordedVideoURL = outputURL
                        self.errorMessage = nil
                        self.recordingDelegate = nil
                    }
                }
            )

            self.recordingDelegate = delegate

            self.movieOutput.startRecording(
                to: fileURL,
                recordingDelegate: delegate
            )

            DispatchQueue.main.async {
                self.lastRecordedVideoURL = nil
                self.errorMessage = nil
                self.isRecording = true
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession()
        }
    }

    private func configureSession() {
        if didConfigureSession {
            DispatchQueue.main.async {
                self.isConfigured = true
            }
            return
        }

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            DispatchQueue.main.async {
                self.errorMessage = "카메라 권한이 허용되지 않았습니다."
            }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            DispatchQueue.main.async {
                self.errorMessage = "후면 카메라를 찾을 수 없습니다."
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "카메라 입력을 세션에 추가할 수 없습니다."
                }
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "카메라 입력 생성 실패: \(error.localizedDescription)"
            }
            return
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "녹화 출력을 세션에 추가할 수 없습니다."
            }
            return
        }

        didConfigureSession = true

        DispatchQueue.main.async {
            self.isConfigured = true
            self.errorMessage = nil
        }
    }

    private static func makeTemporaryMovieURL() -> URL {
        let filename = "kongsoon-recording-\(UUID().uuidString).mov"
        return FileManager.default
            .temporaryDirectory
            .appendingPathComponent(filename)
    }
}

private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let didStartHandler: @Sendable () -> Void
    private let didFinishHandler: @Sendable (URL, Error?) -> Void

    init(
        didStart: @escaping @Sendable () -> Void,
        didFinish: @escaping @Sendable (URL, Error?) -> Void
    ) {
        self.didStartHandler = didStart
        self.didFinishHandler = didFinish
        super.init()
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        didStartHandler()
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        didFinishHandler(outputFileURL, error)
    }
}
