import AVFoundation
import CoreGraphics
import CoreML
import Foundation
import Vision

struct VisionDogEmotionAnalyzer {
    struct FrameSample {
        let time: TimeInterval
        let dogObservation: VNRecognizedObjectObservation?
        let modelPrediction: ModelPrediction?
    }

    struct ModelPrediction {
        let emotion: EmotionState?
        let behavior: BehaviorType?
        let confidence: Double
        let rawLabel: String
    }

    private static let modelResourceNames = [
        "DogBehaviorEmotionClassifier",
        "DogEmotionBehaviorClassifier",
        "DogEmotionClassifier"
    ]

    static func analyzeVideo(
        at url: URL,
        progressHandler: (@MainActor (Double) -> Void)? = nil,
        allowHeuristicFallback: Bool = false
    ) async throws -> DogEmotionAnalysis {
        let coreMLModel = try loadCoreMLModelIfAvailable(allowHeuristicFallback: allowHeuristicFallback)

        let asset = AVURLAsset(url: url)
        let durationSeconds = try await asset.load(.duration).seconds
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw AnalyzerError.invalidAssetDuration
        }

        let frameTimes = buildFrameTimes(duration: durationSeconds)
        var samples: [FrameSample] = []
        samples.reserveCapacity(frameTimes.count)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        for (index, second) in frameTimes.enumerated() {
            try Task.checkCancellation()

            let time = CMTime(seconds: second, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            let dogObservation = try detectDog(in: image)
            let modelPrediction = try predictFromModel(using: coreMLModel, image: image)

            samples.append(
                FrameSample(
                    time: second,
                    dogObservation: dogObservation,
                    modelPrediction: modelPrediction
                )
            )

            let progress = Double(index + 1) / Double(max(frameTimes.count, 1))
            if let progressHandler {
                await progressHandler(progress)
            }
        }

        return buildAnalysis(from: samples, duration: durationSeconds)
    }

    private static func loadCoreMLModelIfAvailable(allowHeuristicFallback: Bool) throws -> VNCoreMLModel? {
        for name in modelResourceNames {
            if let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                let model = try MLModel(contentsOf: modelURL)
                return try VNCoreMLModel(for: model)
            }
        }

        if allowHeuristicFallback {
            return nil
        }

        throw AnalyzerError.modelNotFound(expectedNames: modelResourceNames)
    }

    private static func buildFrameTimes(duration: TimeInterval) -> [TimeInterval] {
        let maxSamples = 30
        let interval = max(0.5, duration / Double(maxSamples))

        var times: [TimeInterval] = []
        var current: TimeInterval = 0

        while current < duration {
            times.append(current)
            current += interval
        }

        if times.last != duration {
            times.append(duration)
        }

        return times
    }

    private static func detectDog(in image: CGImage) throws -> VNRecognizedObjectObservation? {
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        return request.results?
            .compactMap { observation -> VNRecognizedObjectObservation? in
                let labels = observation.labels.map(\.identifier)
                if labels.contains("Dog") || labels.contains("Canine") {
                    return observation
                }
                return nil
            }
            .max(by: { $0.confidence < $1.confidence })
    }

    private static func predictFromModel(using model: VNCoreMLModel?, image: CGImage) throws -> ModelPrediction? {
        guard let model else { return nil }

        var topResult: VNClassificationObservation?

        let request = VNCoreMLRequest(model: model) { request, _ in
            topResult = (request.results as? [VNClassificationObservation])?.first
        }
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        guard let result = topResult else { return nil }

        let parsed = ModelLabelParser.parse(result.identifier)
        return ModelPrediction(
            emotion: parsed.emotion,
            behavior: parsed.behavior,
            confidence: Double(result.confidence),
            rawLabel: result.identifier
        )
    }

    private static func buildAnalysis(from samples: [FrameSample], duration: TimeInterval) -> DogEmotionAnalysis {
        let dogDetections = samples.compactMap(\.dogObservation)
        let predictionSamples = samples.compactMap(\.modelPrediction)

        let detectionRate = Double(dogDetections.count) / Double(max(samples.count, 1))
        let modelCoverage = Double(predictionSamples.count) / Double(max(samples.count, 1))
        let averageModelConfidence = predictionSamples.isEmpty
            ? 0.0
            : predictionSamples.map(\.confidence).reduce(0, +) / Double(predictionSamples.count)

        let movementScore = computeMovementScore(samples: samples)
        let jitterScore = computeJitterScore(samples: samples)

        let (emotionScores, dominantEmotion) = makeEmotionScores(
            predictions: predictionSamples,
            movement: movementScore,
            jitter: jitterScore,
            detectionRate: detectionRate
        )

        let (behaviorScores, dominantBehavior) = makeBehaviorScores(
            predictions: predictionSamples,
            movement: movementScore,
            jitter: jitterScore
        )

        let timeline = makeTimeline(samples: samples, duration: duration)
        let confidence = max(0.40, min(0.98, averageModelConfidence * 0.7 + modelCoverage * 0.2 + detectionRate * 0.1))

        let signals: [AnalysisSignal] = [
            AnalysisSignal(
                title: "모델 적용률",
                detail: "샘플 중 모델 추론이 수행된 비율은 \(Int(modelCoverage * 100))% 입니다.",
                weight: modelCoverage > 0.7 ? .high : (modelCoverage > 0.35 ? .medium : .low)
            ),
            AnalysisSignal(
                title: "강아지 인식률",
                detail: "강아지 객체 인식 비율은 \(Int(detectionRate * 100))% 입니다.",
                weight: detectionRate > 0.7 ? .high : (detectionRate > 0.4 ? .medium : .low)
            ),
            AnalysisSignal(
                title: "모델 평균 신뢰도",
                detail: "프레임 추론 평균 신뢰도는 \(Int(averageModelConfidence * 100))% 입니다.",
                weight: averageModelConfidence > 0.75 ? .high : (averageModelConfidence > 0.45 ? .medium : .low)
            )
        ]

        let summary = "Core ML 모델 추론 결과, 현재 상태는 '\(dominantEmotion.title)' 가능성이 높고 주 행동은 '\(dominantBehavior.title)'으로 추정됩니다."

        return DogEmotionAnalysis(
            createdAt: Date(),
            mode: .uploadedVideo,
            currentState: dominantEmotion,
            currentBehavior: dominantBehavior,
            confidence: confidence,
            emotionScores: emotionScores,
            behaviorScores: behaviorScores,
            signals: signals,
            timeline: timeline,
            summaryText: summary
        )
    }

    private static func computeMovementScore(samples: [FrameSample]) -> Double {
        var movement: Double = 0
        var count: Double = 0

        for pair in zip(samples, samples.dropFirst()) {
            guard let a = pair.0.dogObservation, let b = pair.1.dogObservation else { continue }

            let centerA = CGPoint(x: a.boundingBox.midX, y: a.boundingBox.midY)
            let centerB = CGPoint(x: b.boundingBox.midX, y: b.boundingBox.midY)
            let delta = hypot(centerA.x - centerB.x, centerA.y - centerB.y)

            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height
            let areaDelta = abs(areaA - areaB)

            movement += min(1.0, delta * 1.8 + areaDelta * 1.2)
            count += 1
        }

        if count == 0 {
            return 0.2
        }

        return min(1.0, movement / count)
    }

    private static func computeJitterScore(samples: [FrameSample]) -> Double {
        let boxes = samples.compactMap { $0.dogObservation?.boundingBox }
        guard boxes.count >= 3 else { return 0.2 }

        var turnCount = 0
        var previousXDelta = boxes[1].midX - boxes[0].midX

        for index in 2..<boxes.count {
            let currentXDelta = boxes[index].midX - boxes[index - 1].midX
            if previousXDelta.sign != currentXDelta.sign, abs(currentXDelta) > 0.01 {
                turnCount += 1
            }
            previousXDelta = currentXDelta
        }

        return min(1.0, Double(turnCount) / Double(boxes.count - 2))
    }

    private static func makeEmotionScores(
        predictions: [ModelPrediction],
        movement: Double,
        jitter: Double,
        detectionRate: Double
    ) -> ([EmotionScore], EmotionState) {
        var bucket: [EmotionState: Double] = [:]

        for state in EmotionState.allCases {
            bucket[state] = 0.01
        }

        for prediction in predictions {
            guard let emotion = prediction.emotion else { continue }
            bucket[emotion, default: 0] += prediction.confidence
        }

        if predictions.isEmpty {
            let inferred = inferEmotionHeuristic(movement: movement, jitter: jitter, detectionRate: detectionRate)
            bucket[inferred, default: 0] += 1.0
        }

        let dominant = bucket.max(by: { $0.value < $1.value })?.key ?? .unknown
        let raw = EmotionState.allCases.map { EmotionScore(state: $0, ratio: bucket[$0, default: 0]) }
        return (normalize(raw), dominant)
    }

    private static func makeBehaviorScores(
        predictions: [ModelPrediction],
        movement: Double,
        jitter: Double
    ) -> ([BehaviorScore], BehaviorType) {
        let candidates: [BehaviorType] = [.lying, .sitting, .standing, .walking, .running, .pacing, .eating, .barking, .whining, .unknown]
        var bucket: [BehaviorType: Double] = [:]

        for behavior in candidates {
            bucket[behavior] = 0.01
        }

        for prediction in predictions {
            guard let behavior = prediction.behavior else { continue }
            bucket[behavior, default: 0] += prediction.confidence
        }

        if predictions.isEmpty {
            let inferred = inferBehaviorHeuristic(movement: movement, jitter: jitter)
            bucket[inferred, default: 0] += 1.0
        }

        let dominant = bucket.max(by: { $0.value < $1.value })?.key ?? .unknown
        let raw = candidates.map { BehaviorScore(behavior: $0, ratio: bucket[$0, default: 0]) }
        return (normalize(raw), dominant)
    }

    private static func makeTimeline(samples: [FrameSample], duration: TimeInterval) -> [BehaviorSegment] {
        guard !samples.isEmpty else {
            return [BehaviorSegment(startTime: 0, endTime: duration, behavior: .unknown, emotion: .unknown, confidence: 0.3)]
        }

        let chunkCount = min(6, max(2, samples.count / 5))
        let chunkLength = max(1, Int(ceil(Double(samples.count) / Double(chunkCount))))
        var segments: [BehaviorSegment] = []

        var startIndex = 0
        while startIndex < samples.count {
            let endIndex = min(samples.count, startIndex + chunkLength)
            let chunk = Array(samples[startIndex..<endIndex])

            let movement = computeMovementScore(samples: chunk)
            let jitter = computeJitterScore(samples: chunk)
            let detectionRate = Double(chunk.compactMap(\.dogObservation).count) / Double(max(chunk.count, 1))
            let predictions = chunk.compactMap(\.modelPrediction)

            let (emotionScores, emotion) = makeEmotionScores(
                predictions: predictions,
                movement: movement,
                jitter: jitter,
                detectionRate: detectionRate
            )
            let (_, behavior) = makeBehaviorScores(
                predictions: predictions,
                movement: movement,
                jitter: jitter
            )

            let confidence = max(0.35, min(0.95, emotionScores.first(where: { $0.state == emotion })?.ratio ?? 0.5))

            segments.append(
                BehaviorSegment(
                    startTime: chunk.first?.time ?? 0,
                    endTime: chunk.last?.time ?? duration,
                    behavior: behavior,
                    emotion: emotion,
                    confidence: confidence
                )
            )
            startIndex = endIndex
        }

        return segments
    }

    private static func inferEmotionHeuristic(movement: Double, jitter: Double, detectionRate: Double) -> EmotionState {
        if detectionRate < 0.3 { return .unknown }
        if movement > 0.62 && jitter > 0.5 { return .anxiousStressed }
        if movement > 0.65 { return .happyExcited }
        if movement > 0.38 { return .alert }
        return .relaxed
    }

    private static func inferBehaviorHeuristic(movement: Double, jitter: Double) -> BehaviorType {
        if movement > 0.75 { return .running }
        if movement > 0.55 { return .walking }
        if jitter > 0.55 { return .pacing }
        if movement > 0.25 { return .standing }
        return .lying
    }

    private static func normalize(_ raw: [EmotionScore]) -> [EmotionScore] {
        let total = raw.reduce(0) { $0 + $1.ratio }
        guard total > 0 else { return raw }
        return raw.map { EmotionScore(state: $0.state, ratio: $0.ratio / total) }
    }

    private static func normalize(_ raw: [BehaviorScore]) -> [BehaviorScore] {
        let total = raw.reduce(0) { $0 + $1.ratio }
        guard total > 0 else { return raw }
        return raw.map { BehaviorScore(behavior: $0.behavior, ratio: $0.ratio / total) }
    }
}

private enum ModelLabelParser {
    static func parse(_ raw: String) -> (emotion: EmotionState?, behavior: BehaviorType?) {
        let text = raw.lowercased()

        let emotion = emotionMap.first { text.contains($0.key) }?.value
        let behavior = behaviorMap.first { text.contains($0.key) }?.value

        return (emotion, behavior)
    }

    private static let emotionMap: [(String, EmotionState)] = [
        ("relaxed", .relaxed),
        ("calm", .relaxed),
        ("happy", .happyExcited),
        ("excited", .happyExcited),
        ("anxious", .anxiousStressed),
        ("stress", .anxiousStressed),
        ("alert", .alert),
        ("focus", .alert),
        ("fear", .fearful),
        ("unknown", .unknown)
    ]

    private static let behaviorMap: [(String, BehaviorType)] = [
        ("lying", .lying),
        ("lie", .lying),
        ("sitting", .sitting),
        ("sit", .sitting),
        ("standing", .standing),
        ("stand", .standing),
        ("walking", .walking),
        ("walk", .walking),
        ("running", .running),
        ("run", .running),
        ("pacing", .pacing),
        ("eating", .eating),
        ("eat", .eating),
        ("feeding", .eating),
        ("bark", .barking),
        ("whin", .whining),
        ("unknown", .unknown)
    ]
}

enum AnalyzerError: LocalizedError {
    case invalidAssetDuration
    case modelNotFound(expectedNames: [String])

    var errorDescription: String? {
        switch self {
        case .invalidAssetDuration:
            return "분석 가능한 영상 길이를 확인할 수 없습니다."
        case .modelNotFound(let expectedNames):
            let names = expectedNames.map { "\($0).mlmodelc" }.joined(separator: ", ")
            return "Core ML 모델 파일을 찾지 못했습니다. 앱 번들에 다음 파일 중 하나를 포함하세요: \(names)"
        }
    }
}
