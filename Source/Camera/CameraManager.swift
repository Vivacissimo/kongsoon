import AVFoundation
import SwiftUI
import Combine

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isConfigured = false
    @Published var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "dog-emotion.camera.session.queue")
    private var didConfigureSession = false

    func requestPermissionAndConfigure() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = currentStatus

        switch currentStatus {
        case .authorized:
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }

                if granted {
                    self?.configureSessionIfNeeded()
                }
            }
        case .denied, .restricted:
            errorMessage = "카메라 권한이 필요합니다. 설정에서 카메라 접근을 허용해주세요."
        @unknown default:
            errorMessage = "알 수 없는 카메라 권한 상태입니다."
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.didConfigureSession && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.didConfigureSession {
                self.start()
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            defer {
                self.session.commitConfiguration()
            }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.errorMessage = "후면 카메라를 찾을 수 없습니다."
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
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

            self.didConfigureSession = true

            DispatchQueue.main.async {
                self.isConfigured = true
            }

            self.start()
        }
    }
}
