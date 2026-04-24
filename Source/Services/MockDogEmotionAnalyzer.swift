import Foundation

struct MockDogEmotionAnalyzer {
    static func makeRealtimeResult() -> DogEmotionAnalysis {
        let candidates: [(EmotionState, BehaviorType, Double, [AnalysisSignal], String)] = [
            (
                .relaxed,
                .lying,
                0.86,
                [
                    AnalysisSignal(title: "움직임 안정", detail: "최근 프레임에서 이동량이 낮게 유지됩니다.", weight: .medium),
                    AnalysisSignal(title: "긴장 신호 낮음", detail: "반복적인 서성임이나 회피 움직임이 적습니다.", weight: .medium),
                    AnalysisSignal(title: "소리 신호 없음", detail: "짖음 또는 낑낑거림이 감지되지 않았습니다.", weight: .low)
                ],
                "현재 강아지는 비교적 안정적인 상태로 추정됩니다."
            ),
            (
                .happyExcited,
                .running,
                0.78,
                [
                    AnalysisSignal(title: "활동량 증가", detail: "짧은 시간 동안 움직임 변화가 크게 나타났습니다.", weight: .high),
                    AnalysisSignal(title: "반복 회피 없음", detail: "도망가거나 몸을 낮추는 패턴은 약합니다.", weight: .medium),
                    AnalysisSignal(title: "놀이성 움직임", detail: "이동 방향 변화가 빠르게 반복됩니다.", weight: .medium)
                ],
                "활동량이 높아 흥분 또는 놀이 상태일 가능성이 있습니다."
            ),
            (
                .anxiousStressed,
                .pacing,
                0.81,
                [
                    AnalysisSignal(title: "반복 서성임", detail: "비슷한 경로를 반복해서 이동하는 패턴이 있습니다.", weight: .high),
                    AnalysisSignal(title: "정지 시간 짧음", detail: "한 위치에 머무르는 시간이 짧게 관찰됩니다.", weight: .medium),
                    AnalysisSignal(title: "주의 필요", detail: "장시간 지속되면 보호자 확인이 필요합니다.", weight: .high)
                ],
                "반복적인 움직임 때문에 불안/스트레스 가능성이 높게 추정됩니다."
            ),
            (
                .alert,
                .standing,
                0.74,
                [
                    AnalysisSignal(title: "시선 고정", detail: "몸 방향이 한 지점에 오래 유지됩니다.", weight: .medium),
                    AnalysisSignal(title: "움직임 감소", detail: "움직임은 적지만 자세가 유지됩니다.", weight: .medium),
                    AnalysisSignal(title: "경계 패턴", detail: "갑작스러운 움직임 전 대기 상태로 보입니다.", weight: .low)
                ],
                "특정 대상에 집중하거나 경계하는 상태로 추정됩니다."
            )
        ]

        let selected = candidates.randomElement() ?? candidates[0]

        return DogEmotionAnalysis(
            createdAt: Date(),
            mode: .realtime,
            currentState: selected.0,
            currentBehavior: selected.1,
            confidence: selected.2,
            emotionScores: makeEmotionScores(focus: selected.0),
            behaviorScores: makeBehaviorScores(focus: selected.1),
            signals: selected.3,
            timeline: makeRealtimeTimeline(currentEmotion: selected.0, currentBehavior: selected.1),
            summaryText: selected.4
        )
    }

    static func makeUploadedVideoResult() -> DogEmotionAnalysis {
        DogEmotionAnalysis(
            createdAt: Date(),
            mode: .uploadedVideo,
            currentState: .anxiousStressed,
            currentBehavior: .pacing,
            confidence: 0.79,
            emotionScores: [
                EmotionScore(state: .relaxed, ratio: 0.26),
                EmotionScore(state: .happyExcited, ratio: 0.14),
                EmotionScore(state: .anxiousStressed, ratio: 0.38),
                EmotionScore(state: .alert, ratio: 0.15),
                EmotionScore(state: .fearful, ratio: 0.04),
                EmotionScore(state: .unknown, ratio: 0.03)
            ],
            behaviorScores: [
                BehaviorScore(behavior: .lying, ratio: 0.18),
                BehaviorScore(behavior: .sitting, ratio: 0.11),
                BehaviorScore(behavior: .standing, ratio: 0.17),
                BehaviorScore(behavior: .walking, ratio: 0.18),
                BehaviorScore(behavior: .pacing, ratio: 0.29),
                BehaviorScore(behavior: .barking, ratio: 0.07)
            ],
            signals: [
                AnalysisSignal(title: "반복 서성임", detail: "01:12 이후 비슷한 구간을 반복 이동합니다.", weight: .high),
                AnalysisSignal(title: "짧은 정지 구간", detail: "한 위치에 오래 머무는 구간이 적습니다.", weight: .medium),
                AnalysisSignal(title: "소리 이벤트", detail: "중간 구간에서 짖음으로 보이는 오디오 이벤트가 있습니다.", weight: .medium),
                AnalysisSignal(title: "주의 구간", detail: "불안 추정 구간이 1분 이상 이어집니다.", weight: .high)
            ],
            timeline: [
                BehaviorSegment(startTime: 0, endTime: 24, behavior: .lying, emotion: .relaxed, confidence: 0.83),
                BehaviorSegment(startTime: 25, endTime: 48, behavior: .walking, emotion: .happyExcited, confidence: 0.71),
                BehaviorSegment(startTime: 49, endTime: 93, behavior: .pacing, emotion: .anxiousStressed, confidence: 0.82),
                BehaviorSegment(startTime: 94, endTime: 121, behavior: .standing, emotion: .alert, confidence: 0.76),
                BehaviorSegment(startTime: 122, endTime: 160, behavior: .pacing, emotion: .anxiousStressed, confidence: 0.79)
            ],
            summaryText: "업로드된 영상에서는 중반 이후 반복 서성임과 경계 패턴이 증가해 불안/스트레스 가능성이 높게 추정됩니다."
        )
    }

    private static func makeEmotionScores(focus: EmotionState) -> [EmotionScore] {
        var scores: [EmotionScore] = []

        for state in EmotionState.allCases {
            if state == focus {
                scores.append(EmotionScore(state: state, ratio: 0.48))
            } else if state == .unknown {
                scores.append(EmotionScore(state: state, ratio: 0.05))
            } else {
                scores.append(EmotionScore(state: state, ratio: Double.random(in: 0.05...0.18)))
            }
        }

        let total = scores.reduce(0) { $0 + $1.ratio }
        return scores.map { EmotionScore(state: $0.state, ratio: $0.ratio / total) }
    }

    private static func makeBehaviorScores(focus: BehaviorType) -> [BehaviorScore] {
        let baseBehaviors: [BehaviorType] = [.lying, .sitting, .standing, .walking, .running, .pacing]
        var scores: [BehaviorScore] = []

        for behavior in baseBehaviors {
            if behavior == focus {
                scores.append(BehaviorScore(behavior: behavior, ratio: 0.42))
            } else {
                scores.append(BehaviorScore(behavior: behavior, ratio: Double.random(in: 0.04...0.18)))
            }
        }

        let total = scores.reduce(0) { $0 + $1.ratio }
        return scores.map { BehaviorScore(behavior: $0.behavior, ratio: $0.ratio / total) }
    }

    private static func makeRealtimeTimeline(currentEmotion: EmotionState, currentBehavior: BehaviorType) -> [BehaviorSegment] {
        [
            BehaviorSegment(startTime: 0, endTime: 10, behavior: .standing, emotion: .alert, confidence: 0.70),
            BehaviorSegment(startTime: 11, endTime: 22, behavior: .walking, emotion: .happyExcited, confidence: 0.73),
            BehaviorSegment(startTime: 23, endTime: 35, behavior: currentBehavior, emotion: currentEmotion, confidence: 0.80)
        ]
    }
}
