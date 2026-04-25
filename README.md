# kongsoon UI MVP

SwiftUI 기반 강아지 감정/행동 분석 앱 UI MVP입니다.

## 포함 기능

- 홈 화면
- 실시간 카메라 분석 화면
- 기존 영상 선택/분석 화면
- 감정 상태 카드
- 행동/감정 비율 리포트
- 감정 판단 근거 리스트
- 시간대별 타임라인 UI
- 카메라 프리뷰 연결
- PhotosPicker 영상 선택 연결
- Core ML + Vision 기반 실제 분석 엔진(업로드/녹화 영상)

## Xcode 적용 방법

1. Xcode에서 `iOS App` 템플릿으로 새 프로젝트를 만듭니다.
2. Interface는 `SwiftUI`, Language는 `Swift`로 선택합니다.
3. 이 폴더 안의 `kongsoon` 하위 Swift 파일들을 프로젝트에 추가합니다.
4. 기존 `ContentView.swift`, `AppNameApp.swift`와 이름이 겹치면 삭제하거나 아래 파일명에 맞춰 교체합니다.
5. `Info.plist`에 아래 권한 문구를 추가합니다.

```xml
<key>NSCameraUsageDescription</key>
<string>강아지의 행동과 감정 상태를 실시간으로 분석하기 위해 카메라 접근이 필요합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>강아지의 짖음, 낑낑거림 등 소리를 분석하기 위해 마이크 접근이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>기존에 촬영한 강아지 영상을 선택해 분석하기 위해 사진 보관함 접근이 필요합니다.</string>
```

## 현재 상태

`VisionDogEmotionAnalyzer`는 앱 번들에 포함된 Core ML 모델(`DogBehaviorEmotionClassifier.mlmodelc` 등)을 우선 사용해 프레임 단위 추론을 수행하고, Vision 객체 인식 결과와 함께 리포트를 생성합니다.
실시간 스트리밍 중 화면 표시는 Mock 상태를 사용하지만, 녹화 종료 후에는 Core ML 기반 실제 영상 분석 결과로 리포트를 생성합니다.
