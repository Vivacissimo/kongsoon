from __future__ import annotations

import os
import tempfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from typing import Any

import cv2
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image
from transformers import pipeline


MODEL_ID = os.environ.get("KONGSOON_MODEL_ID", "Dewa/dog_emotion_v2")
MAX_FRAMES = int(os.environ.get("KONGSOON_MAX_FRAMES", "24"))

app = FastAPI(title="Kongsoon Desktop AI Server")
classifier = None


@dataclass
class FramePrediction:
    time: float
    label: str
    score: float
    scores: dict[str, float]
    motion: float


@app.on_event("startup")
def load_model() -> None:
    global classifier
    classifier = pipeline("image-classification", model=MODEL_ID)


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "model": MODEL_ID}


@app.post("/analyze")
async def analyze(file: UploadFile = File(...)) -> dict[str, Any]:
    if not file.content_type or not file.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="video file is required")

    suffix = os.path.splitext(file.filename or "")[1] or ".mov"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
        temp_path = temp_file.name
        temp_file.write(await file.read())

    try:
        frames = sample_video_frames(temp_path, MAX_FRAMES)
        if not frames:
            raise HTTPException(status_code=422, detail="could not sample video frames")

        predictions = predict_frames(frames)
        return build_report(predictions, duration=frames[-1][0])
    finally:
        try:
            os.remove(temp_path)
        except OSError:
            pass


def sample_video_frames(path: str, max_frames: int) -> list[tuple[float, np.ndarray, float]]:
    capture = cv2.VideoCapture(path)
    if not capture.isOpened():
        return []

    fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    duration = total_frames / fps if total_frames > 0 else 0

    if total_frames <= 0:
        capture.release()
        return []

    frame_indices = np.linspace(0, max(total_frames - 1, 0), num=min(max_frames, total_frames), dtype=int)
    frames: list[tuple[float, np.ndarray, float]] = []
    previous_gray = None

    for frame_index in frame_indices:
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(frame_index))
        ok, frame = capture.read()
        if not ok:
            continue

        resized = cv2.resize(frame, (224, 224))
        gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
        motion = 0.0
        if previous_gray is not None:
            motion = float(np.mean(cv2.absdiff(gray, previous_gray)) / 255.0)
        previous_gray = gray

        time = min(float(frame_index) / fps, duration)
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        frames.append((time, rgb, motion))

    capture.release()
    return frames


def predict_frames(frames: list[tuple[float, np.ndarray, float]]) -> list[FramePrediction]:
    if classifier is None:
        raise HTTPException(status_code=503, detail="model is not loaded")

    predictions: list[FramePrediction] = []
    for time, frame, motion in frames:
        image = Image.fromarray(frame)
        raw_results = classifier(image)
        scores = {normalize_label(item["label"]): float(item["score"]) for item in raw_results}
        label, score = max(scores.items(), key=lambda item: item[1])
        predictions.append(FramePrediction(time=time, label=label, score=score, scores=scores, motion=motion))

    return predictions


def build_report(predictions: list[FramePrediction], duration: float) -> dict[str, Any]:
    emotion_totals: dict[str, float] = defaultdict(float)
    for prediction in predictions:
        for label, score in prediction.scores.items():
            emotion_totals[map_emotion(label)] += score

    emotion_scores = normalize_scores(emotion_totals, ["relaxed", "happyExcited", "anxiousStressed", "alert", "fearful", "unknown"])
    dominant_emotion = max(emotion_scores, key=lambda item: item["ratio"])["state"]

    average_motion = sum(item.motion for item in predictions) / max(len(predictions), 1)
    dominant_behavior = infer_behavior(average_motion)
    behavior_scores = make_behavior_scores(dominant_behavior, average_motion)
    confidence = sum(item.score for item in predictions) / max(len(predictions), 1)

    return {
        "createdAt": None,
        "mode": "uploadedVideo",
        "currentState": dominant_emotion,
        "currentBehavior": dominant_behavior,
        "confidence": round(float(confidence), 4),
        "emotionScores": emotion_scores,
        "behaviorScores": behavior_scores,
        "signals": [
            {
                "title": "데스크탑 AI 모델",
                "detail": f"{MODEL_ID} 모델로 {len(predictions)}개 프레임을 분석했습니다.",
                "weight": "high",
            },
            {
                "title": "평균 움직임",
                "detail": f"프레임 간 움직임 점수는 {int(average_motion * 100)}% 입니다.",
                "weight": "medium" if average_motion < 0.18 else "high",
            },
            {
                "title": "주요 프레임 감정",
                "detail": summarize_labels(predictions),
                "weight": "medium",
            },
        ],
        "timeline": make_timeline(predictions, duration),
        "summaryText": f"데스크탑 AI 서버 분석 결과, 현재 상태는 '{korean_emotion_title(dominant_emotion)}' 가능성이 가장 높고 주 행동은 '{korean_behavior_title(dominant_behavior)}'으로 추정됩니다.",
    }


def normalize_label(label: str) -> str:
    return label.lower().replace("label_", "").replace(" ", "_")


def map_emotion(label: str) -> str:
    if "relaxed" in label or "calm" in label:
        return "relaxed"
    if "happy" in label:
        return "happyExcited"
    if "angry" in label:
        return "anxiousStressed"
    if "sad" in label:
        return "fearful"
    return "unknown"


def normalize_scores(totals: dict[str, float], keys: list[str]) -> list[dict[str, Any]]:
    total = sum(totals.values())
    if total <= 0:
        return [{"state": key, "ratio": 1.0 if key == "unknown" else 0.0} for key in keys]
    return [{"state": key, "ratio": round(float(totals.get(key, 0.0) / total), 4)} for key in keys]


def infer_behavior(motion: float) -> str:
    if motion > 0.22:
        return "running"
    if motion > 0.12:
        return "walking"
    if motion > 0.05:
        return "standing"
    return "lying"


def make_behavior_scores(dominant: str, motion: float) -> list[dict[str, Any]]:
    base = {
        "lying": max(0.05, 0.45 - motion),
        "sitting": 0.10,
        "standing": 0.18 + min(motion, 0.12),
        "walking": min(0.40, motion * 1.8),
        "running": min(0.35, motion * 1.2),
        "pacing": min(0.22, motion),
        "eating": 0.03,
        "barking": 0.02,
        "whining": 0.02,
        "unknown": 0.03,
    }
    base[dominant] += 0.25
    total = sum(base.values())
    return [{"behavior": key, "ratio": round(float(value / total), 4)} for key, value in base.items()]


def make_timeline(predictions: list[FramePrediction], duration: float) -> list[dict[str, Any]]:
    if not predictions:
        return []

    chunk_size = max(1, len(predictions) // 5)
    segments = []
    for start in range(0, len(predictions), chunk_size):
        chunk = predictions[start : start + chunk_size]
        labels = [map_emotion(item.label) for item in chunk]
        emotion = Counter(labels).most_common(1)[0][0]
        motion = sum(item.motion for item in chunk) / max(len(chunk), 1)
        confidence = sum(item.score for item in chunk) / max(len(chunk), 1)
        segments.append(
            {
                "startTime": chunk[0].time,
                "endTime": chunk[-1].time if chunk[-1].time > chunk[0].time else min(duration, chunk[0].time + 1),
                "behavior": infer_behavior(motion),
                "emotion": emotion,
                "confidence": round(float(confidence), 4),
            }
        )
    return segments


def summarize_labels(predictions: list[FramePrediction]) -> str:
    counts = Counter(map_emotion(item.label) for item in predictions)
    parts = [f"{korean_emotion_title(label)} {count}프레임" for label, count in counts.most_common(3)]
    return ", ".join(parts)


def korean_emotion_title(value: str) -> str:
    return {
        "relaxed": "편안함",
        "happyExcited": "기쁨/흥분",
        "anxiousStressed": "불안/짜증",
        "alert": "경계/집중",
        "fearful": "두려움",
        "unknown": "판단 불가",
    }.get(value, "판단 불가")


def korean_behavior_title(value: str) -> str:
    return {
        "lying": "누워있음",
        "sitting": "앉아있음",
        "standing": "서있음",
        "walking": "걷기",
        "running": "뛰기",
        "pacing": "서성임",
        "barking": "짖음",
        "whining": "낑낑거림",
        "eating": "식사",
        "unknown": "판단 불가",
    }.get(value, "판단 불가")

