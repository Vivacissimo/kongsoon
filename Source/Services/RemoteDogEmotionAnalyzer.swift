import Foundation

extension EmotionState: Decodable {}
extension BehaviorType: Decodable {}

struct RemoteDogEmotionAnalyzer {
    static let endpoint = URL(string: "http://192.168.35.113:8000/analyze")!

    static func analyzeVideo(at url: URL) async throws -> DogEmotionAnalysis {
        var request = URLRequest(url: endpoint)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let videoData = try Data(contentsOf: url)
        request.httpBody = makeMultipartBody(
            fileData: videoData,
            filename: url.lastPathComponent,
            mimeType: "video/quicktime",
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw RemoteAnalyzerError.invalidResponse
        }

        let report = try JSONDecoder().decode(RemoteAnalysisResponse.self, from: data)
        return report.analysis
    }

    private static func makeMultipartBody(
        fileData: Data,
        filename: String,
        mimeType: String,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }
}

private enum RemoteAnalyzerError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "데스크탑 AI 서버 응답을 읽을 수 없습니다."
        }
    }
}

private struct RemoteAnalysisResponse: Decodable {
    let mode: String
    let currentState: EmotionState
    let currentBehavior: BehaviorType
    let confidence: Double
    let emotionScores: [RemoteEmotionScore]
    let behaviorScores: [RemoteBehaviorScore]
    let signals: [RemoteSignal]
    let timeline: [RemoteBehaviorSegment]
    let summaryText: String

    var analysis: DogEmotionAnalysis {
        DogEmotionAnalysis(
            createdAt: Date(),
            mode: mode == "realtime" ? .realtime : .uploadedVideo,
            currentState: currentState,
            currentBehavior: currentBehavior,
            confidence: confidence,
            emotionScores: emotionScores.map { EmotionScore(state: $0.state, ratio: $0.ratio) },
            behaviorScores: behaviorScores.map { BehaviorScore(behavior: $0.behavior, ratio: $0.ratio) },
            signals: signals.map { AnalysisSignal(title: $0.title, detail: $0.detail, weight: $0.signalWeight) },
            timeline: timeline.map {
                BehaviorSegment(
                    startTime: $0.startTime,
                    endTime: $0.endTime,
                    behavior: $0.behavior,
                    emotion: $0.emotion,
                    confidence: $0.confidence
                )
            },
            summaryText: summaryText
        )
    }
}

private struct RemoteEmotionScore: Decodable {
    let state: EmotionState
    let ratio: Double
}

private struct RemoteBehaviorScore: Decodable {
    let behavior: BehaviorType
    let ratio: Double
}

private struct RemoteSignal: Decodable {
    let title: String
    let detail: String
    let weight: String

    var signalWeight: SignalWeight {
        switch weight {
        case "high":
            return .high
        case "medium":
            return .medium
        default:
            return .low
        }
    }
}

private struct RemoteBehaviorSegment: Decodable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let behavior: BehaviorType
    let emotion: EmotionState
    let confidence: Double
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
