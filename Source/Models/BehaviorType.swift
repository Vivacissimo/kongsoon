import SwiftUI

enum BehaviorType: String, CaseIterable, Identifiable {
    case lying
    case sitting
    case standing
    case walking
    case running
    case pacing
    case barking
    case whining
    case eating
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lying:
            return "누워있음"
        case .sitting:
            return "앉아있음"
        case .standing:
            return "서있음"
        case .walking:
            return "걷기"
        case .running:
            return "뛰기"
        case .pacing:
            return "서성임"
        case .barking:
            return "짖음"
        case .whining:
            return "낑낑거림"
        case .eating:
            return "식사"
        case .unknown:
            return "판단 불가"
        }
    }

    var iconName: String {
        switch self {
        case .lying:
            return "bed.double.fill"
        case .sitting:
            return "figure.seated.side"
        case .standing:
            return "figure.stand"
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .pacing:
            return "arrow.left.and.right"
        case .barking:
            return "speaker.wave.2.fill"
        case .whining:
            return "waveform"
        case .eating:
            return "fork.knife"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
