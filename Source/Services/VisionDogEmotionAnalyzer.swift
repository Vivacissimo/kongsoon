import AVFoundation
import CoreGraphics
import Foundation
import Vision

struct VisionDogEmotionAnalyzer {
    struct FrameSample {
        let time: TimeInterval
        let observation: VNRecognizedObjectObservation?
    }

    static func analyzeVideo(
        at url: URL,
        progressHandler: (@MainActor (Double) -> Void)? = nil
    ) async throws -> DogEmotionAnalysis {
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
            let observation = try detectDog(in: image)
            samples.append(FrameSample(time: second, observation: observation))

            let progress = Double(index + 1) / Double(max(frameTimes.count, 1))
            if let progressHandler {
                await progressHandler(progress)
            }
        }

        return buildAnalysis(from: samples, duration: durationSeconds)
    }

    private static func buildFrameTimes(duration: TimeInterval) -> [TimeInterval] {
        let maxSamples = 24
        let interval = max(0.6, duration / Double(maxSamples))

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

    private static func buildAnalysis(from samples: [FrameSample], duration: TimeInterval) -> DogEmotionAnalysis {
        let detected = samples.compactMap(\.observation)
        let detectionRate = Double(detected.count) / Double(max(samples.count, 1))
        let averageConfidence = detected.isEmpty
            ? 0.35
            : detected.map { Double($0.confidence) }.reduce(0, +) / Double(detected.count)

        let movementScore = computeMovementScore(samples: samples)
        let jitterScore = computeJitterScore(samples: samples)

        let emotion = inferEmotion(movement: movementScore, jitter: jitterScore, detectionRate: detectionRate)
        let behavior = inferBehavior(movement: movementScore, jitter: jitterScore)
        let confidence = max(0.45, min(0.95, (averageConfidence * 0.7) + (detectionRate * 0.3)))

        let emotionScores = makeEmotionScores(
            dominant: emotion,
            movement: movementScore,
            jitter: jitterScore
        )
        let behaviorScores = makeBehaviorScores(
            dominant: behavior,
            movement: movementScore,
            jitter: jitterScore
        )
        let timeline = makeTimeline(samples: samples, duration: duration)

        let signals: [AnalysisSignal] = [
            AnalysisSignal(
                title: "반려견 인식률",
                detail: "전체 샘플 중 반려견 인식 비율은 \(Int(detectionRate * 100))% 입니다.",
                weight: detectionRate > 0.75 ? .high : (detectionRate > 0.45 ? .medium : .low)
            ),
            AnalysisSignal(
                title: "움직임 강도",
                detail: "프레임 간 중심 이동량/크기 변화를 합산한 점수는 \(Int(movementScore * 100))점입니다.",
                weight: movementScore > 0.6 ? .high : (movementScore > 0.3 ? .medium : .low)
            ),
            AnalysisSignal(
                title: "패턴 변동성",
                detail: "행동 패턴의 흔들림(jitter) 지수는 \(Int(jitterScore * 100))점입니다.",
                weight: jitterScore > 0.55 ? .high : (jitterScore > 0.25 ? .medium : .low)
            )
        ]

        let summary = "영상 기반 비전 분석 결과, 현재 상태는 '\(emotion.title)' 가능성이 높으며 주 행동은 '\(behavior.title)'으로 추정됩니다."

        return DogEmotionAnalysis(
            createdAt: Date(),
            mode: .uploadedVideo,
            currentState: emotion,
            currentBehavior: behavior,
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
            guard let a = pair.0.observation, let b = pair.1.observation else { continue }

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
        let boxes = samples.compactMap { $0.observation?.boundingBox }
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

    private static func inferEmotion(movement: Double, jitter: Double, detectionRate: Double) -> EmotionState {
        if detectionRate < 0.35 {
            return .unknown
        }

        if movement > 0.62 && jitter > 0.5 {
            return .anxiousStressed
        }

        if movement > 0.65 {
            return .happyExcited
        }

        if movement > 0.38 {
            return .alert
        }

        return .relaxed
    }

    private static func inferBehavior(movement: Double, jitter: Double) -> BehaviorType {
        if movement > 0.75 {
            return .running
        }

        if movement > 0.55 {
            return .walking
        }

        if jitter > 0.55 {
            return .pacing
        }

        if movement > 0.25 {
            return .standing
        }

        return .lying
    }

    private static func makeEmotionScores(dominant: EmotionState, movement: Double, jitter: Double) -> [EmotionScore] {
        let baseline: [EmotionState: Double] = [
            .relaxed: 0.2,
            .happyExcited: 0.18,
            .anxiousStressed: 0.18,
            .alert: 0.18,
            .fearful: 0.1,
            .unknown: 0.16
        ]

        return normalize(
            EmotionState.allCases.map { state in
                var value = baseline[state, default: 0.1]
                if state == dominant { value += 0.45 }
                if state == .anxiousStressed { value += jitter * 0.15 }
                if state == .happyExcited { value += movement * 0.12 }
                if state == .unknown { value += (1 - movement) * 0.05 }
                return EmotionScore(state: state, ratio: value)
            }
        )
    }

    private static func makeBehaviorScores(dominant: BehaviorType, movement: Double, jitter: Double) -> [BehaviorScore] {
        let candidates: [BehaviorType] = [.lying, .sitting, .standing, .walking, .running, .pacing]

        return normalize(
            candidates.map { behavior in
                var value = 0.14
                if behavior == dominant { value += 0.45 }
                if behavior == .running { value += movement * 0.15 }
                if behavior == .walking { value += movement * 0.08 }
                if behavior == .pacing { value += jitter * 0.18 }
                if behavior == .lying { value += (1 - movement) * 0.12 }
                return BehaviorScore(behavior: behavior, ratio: value)
            }
        )
    }

    private static func makeTimeline(samples: [FrameSample], duration: TimeInterval) -> [BehaviorSegment] {
        guard !samples.isEmpty else {
            return [
                BehaviorSegment(startTime: 0, endTime: duration, behavior: .unknown, emotion: .unknown, confidence: 0.3)
            ]
        }

        let chunkCount = min(5, max(2, samples.count / 4))
        let chunkLength = max(1, Int(ceil(Double(samples.count) / Double(chunkCount))))
        var segments: [BehaviorSegment] = []

        var startIndex = 0
        while startIndex < samples.count {
            let endIndex = min(samples.count, startIndex + chunkLength)
            let chunk = Array(samples[startIndex..<endIndex])
            let movement = computeMovementScore(samples: chunk)
            let jitter = computeJitterScore(samples: chunk)
            let detectionRate = Double(chunk.compactMap(\.observation).count) / Double(max(chunk.count, 1))

            let emotion = inferEmotion(movement: movement, jitter: jitter, detectionRate: detectionRate)
            let behavior = inferBehavior(movement: movement, jitter: jitter)

            let startTime = chunk.first?.time ?? 0
            let endTime = chunk.last?.time ?? duration
            let confidence = max(0.4, min(0.92, detectionRate * 0.7 + movement * 0.2 + 0.1))

            segments.append(
                BehaviorSegment(
                    startTime: startTime,
                    endTime: endTime,
                    behavior: behavior,
                    emotion: emotion,
                    confidence: confidence
                )
            )

            startIndex = endIndex
        }

        return segments
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

enum AnalyzerError: LocalizedError {
    case invalidAssetDuration

    var errorDescription: String? {
        switch self {
        case .invalidAssetDuration:
            return "분석 가능한 영상 길이를 확인할 수 없습니다."
        }
    }
}
