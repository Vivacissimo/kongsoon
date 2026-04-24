import Foundation

struct EmotionScore: Identifiable {
    let id = UUID()
    let state: EmotionState
    let ratio: Double
}

struct BehaviorScore: Identifiable {
    let id = UUID()
    let behavior: BehaviorType
    let ratio: Double
}

struct AnalysisSignal: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let weight: SignalWeight
}

enum SignalWeight {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low:
            return "낮음"
        case .medium:
            return "중간"
        case .high:
            return "높음"
        }
    }
}

struct BehaviorSegment: Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let behavior: BehaviorType
    let emotion: EmotionState
    let confidence: Double

    var timeRangeText: String {
        "\(startTime.mmss) - \(endTime.mmss)"
    }
}

struct DogEmotionAnalysis: Identifiable {
    let id = UUID()
    let createdAt: Date
    let mode: AnalysisMode
    let currentState: EmotionState
    let currentBehavior: BehaviorType
    let confidence: Double
    let emotionScores: [EmotionScore]
    let behaviorScores: [BehaviorScore]
    let signals: [AnalysisSignal]
    let timeline: [BehaviorSegment]
    let summaryText: String
}

enum AnalysisMode: String {
    case realtime
    case uploadedVideo

    var title: String {
        switch self {
        case .realtime:
            return "실시간 분석"
        case .uploadedVideo:
            return "영상 분석"
        }
    }
}

extension TimeInterval {
    var mmss: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
