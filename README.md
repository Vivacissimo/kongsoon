# Kongsoon

Kongsoon은 iOS 환경에서 강아지의 행동과 감정 상태를 분석하는 것을 목표로 하는 SwiftUI 기반 애플리케이션입니다.

현재 버전은 실제 AI 모델이 연결되기 전 단계의 UI MVP입니다.  
실시간 카메라 화면, 기존 영상 선택, 분석 결과 리포트 화면, 감정/행동 비율 표시, 판단 근거 표시 등의 기본 앱 흐름을 구현했습니다.

---

## Project Goal

Kongsoon의 최종 목표는 다음과 같습니다.

- iPhone 카메라를 통한 강아지 실시간 분석
- 기존에 촬영한 강아지 영상 업로드 분석
- 강아지 행동 분석
- 강아지 감정/상태 추정
- 분석 결과 리포트 제공
- 추후 Core ML 기반 온디바이스 AI 추론 적용

---

## Current Status

현재 구현된 기능은 다음과 같습니다.

- SwiftUI 기반 홈 화면
- 실시간 분석 화면
- 카메라 프리뷰 연결
- 기존 영상 선택 화면
- 분석 결과 리포트 화면
- Mock 분석 엔진
- 감정 상태 카드
- 행동/감정 비율 UI
- 판단 근거 리스트
- 타임라인 UI

현재 분석 결과는 실제 AI 추론 결과가 아니라 `MockDogEmotionAnalyzer`에서 생성하는 테스트용 데이터입니다.

---

## Main Features

### 1. Realtime Analysis

실시간 분석 화면에서는 iPhone 카메라를 통해 강아지를 촬영하는 상황을 가정합니다.

현재는 카메라 프리뷰와 Mock 분석 결과를 표시합니다.

추후 목표:

- 카메라 프레임 추출
- Core ML 모델 추론
- 강아지 탐지
- 행동 분류
- 감정/상태 추정
- 실시간 결과 오버레이 표시

---

### 2. Video Analysis

사용자가 기존에 촬영한 영상을 선택하면 분석 결과 화면으로 이동합니다.

현재는 영상 선택 후 Mock 분석 결과를 표시합니다.

추후 목표:

- 영상 프레임 샘플링
- 프레임별 AI 추론
- 시간대별 행동 분석
- 감정 상태 타임라인 생성
- 분석 리포트 저장

---

### 3. Emotion State Report

분석 결과 화면에서는 다음 정보를 표시합니다.

- 현재 추정 감정 상태
- 신뢰도
- 행동 비율
- 감정 비율
- 감지된 판단 근거
- 시간대별 분석 타임라인

예상 감정 상태:

- Relaxed
- Happy / Excited
- Anxious / Stressed
- Alert
- Fearful
- Unknown

---

## Tech Stack

### iOS

- Swift
- SwiftUI
- AVFoundation
- PhotosUI
- Combine

### Future Plan

- Core ML
- Vision
- FastAPI
- PostgreSQL
- Redis
- Docker
- Kubernetes
- GitHub Actions
- Prometheus
- Grafana

---

## Project Structure

```text
Kongsoon/
├── Camera/
│   ├── CameraManager.swift
│   └── CameraPreview.swift
│
├── Components/
│   ├── EmotionHeaderCard.swift
│   ├── PrimaryActionButton.swift
│   ├── ScoreBarList.swift
│   ├── SignalListView.swift
│   └── TimelineListView.swift
│
├── Models/
│   ├── AnalysisModels.swift
│   ├── BehaviorType.swift
│   └── EmotionState.swift
│
├── Services/
│   └── MockDogEmotionAnalyzer.swift
│
├── Transferables/
│   └── Movie.swift
│
├── Views/
│   ├── HomeView.swift
│   ├── RealtimeAnalysisView.swift
│   ├── VideoAnalysisView.swift
│   └── AnalysisReportView.swift
│
├── ContentView.swift
└── kongsoonApp.swift
