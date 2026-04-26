# Kongsoon Desktop AI Server

Mac에서 PyTorch/Hugging Face 모델로 영상 분석을 수행하고, iPhone 앱은 영상을 업로드한 뒤 JSON 리포트를 받는 테스트 서버입니다.

## 모델

기본 모델은 `Dewa/dog_emotion_v2`입니다.

- 입력: 강아지 이미지 프레임
- 출력: `sad`, `happy`, `angry`, `relaxed`
- 장점: Hugging Face `transformers` 이미지 분류 파이프라인으로 바로 테스트 가능
- 단점: 첫 실행 시 약 343MB 모델 다운로드가 필요

나중에 더 가벼운 모델이 필요하면 `shinyice/densenet121-dog-emotions`를 별도 로더로 붙이면 됩니다.

## 설치

```bash
cd /Users/joon/Desktop/dev/Kongsoon/AI_Server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 실행

```bash
source .venv/bin/activate
uvicorn server:app --host 0.0.0.0 --port 8000
```

Mac의 Wi-Fi IP를 확인합니다.

```bash
ipconfig getifaddr en0
```

iPhone과 Mac이 같은 Wi-Fi에 있으면 앱에서는 다음 주소로 업로드합니다.

```text
http://<MAC_IP>:8000/analyze
```

예:

```text
http://192.168.0.12:8000/analyze
```

## 수동 테스트

```bash
curl -X POST \
  -F "file=@/path/to/dog-video.mov" \
  http://127.0.0.1:8000/analyze
```

## iOS 연동 설계

1. 앱에서 PhotosPicker 또는 녹화 결과 URL을 받습니다.
2. `multipart/form-data`로 `/analyze`에 영상 파일을 업로드합니다.
3. 서버는 프레임을 샘플링하고 각 프레임을 이미지 분류 모델에 넣습니다.
4. 서버는 감정 비율, 행동 추정, 타임라인, 판단 근거를 JSON으로 반환합니다.
5. 앱은 JSON을 `DogEmotionAnalysis`로 매핑해서 기존 리포트 UI에 표시합니다.
6. 서버 연결 실패 시 기존 `VisionDogEmotionAnalyzer` fallback으로 대체합니다.

개발 중 로컬 HTTP를 쓰려면 iOS 앱의 Info.plist에 App Transport Security 예외가 필요합니다. 테스트 단계에서는 `NSAllowsLocalNetworking` 또는 임시 `NSAllowsArbitraryLoads`를 사용할 수 있고, 배포 전에는 HTTPS 서버로 바꾸는 것이 좋습니다.

