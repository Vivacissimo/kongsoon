import SwiftUI

enum EmotionState: String, CaseIterable, Identifiable {
    case relaxed
    case happyExcited
    case anxiousStressed
    case alert
    case fearful
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed:
            return "편안함"
        case .happyExcited:
            return "기쁨/흥분"
        case .anxiousStressed:
            return "불안/스트레스"
        case .alert:
            return "경계/집중"
        case .fearful:
            return "두려움"
        case .unknown:
            return "판단 불가"
        }
    }

    var description: String {
        switch self {
        case .relaxed:
            return "몸 움직임이 안정적이고 긴장 신호가 낮습니다."
        case .happyExcited:
            return "활동량이 높고 긍정적인 흥분 신호가 보입니다."
        case .anxiousStressed:
            return "반복 움직임이나 불안 신호가 함께 감지됩니다."
        case .alert:
            return "시선 또는 몸 방향이 특정 대상에 집중되어 있습니다."
        case .fearful:
            return "회피, 몸 낮춤, 긴장 신호가 관찰됩니다."
        case .unknown:
            return "화면 품질이나 신호가 부족해 판단하기 어렵습니다."
        }
    }

    var iconName: String {
        switch self {
        case .relaxed:
            return "leaf.fill"
        case .happyExcited:
            return "sparkles"
        case .anxiousStressed:
            return "exclamationmark.triangle.fill"
        case .alert:
            return "eye.fill"
        case .fearful:
            return "cloud.bolt.rain.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .relaxed:
            return .green
        case .happyExcited:
            return .orange
        case .anxiousStressed:
            return .red
        case .alert:
            return .blue
        case .fearful:
            return .purple
        case .unknown:
            return .gray
        }
    }
}
