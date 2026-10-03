# Smart Alert VTOL - 개발 작업 일지 (v1.3 연동 및 검증)
- **작성일**: 2026년 9월 20일
- **프로젝트 리더**: 남규행
- **참여**: 클론, 미스 G, 비코, 푼수, 코미냥

---

## 🚀 오늘 완료된 핵심 작업 내용

### 1. Flutter 모바일 앱 (`smart_alarm_app`) 에셋 및 빌드 환경 정비
- **SDK 제약 조건 수정**: `pubspec.yaml` 파일에 Dart SDK 버전을 정상적으로 인식하도록 환경 설정 반영 완료 (`sdk: '^3.13.0'`).
- **에셋(Asset) 경로 및 파일 정비**: 
  - `assets/` 폴더를 `smart_alarm_app` 내부 루트로 정확히 배치.
  - 윈도우 환경에서 확장자 숨기기로 인해 발생했던 중복 파일명 문제 해결 (`fire1.jpg.jpg` ➔ **`fire1.jpg` ~ `fire4.jpg`** 로 확장자 중복 제거 완료).
  - `pubspec.yaml` 내 `assets:` 경로 매핑 정상화 (`assets/fire1.jpg` ~ `assets/fire4.jpg`).

### 2. 실증 검증 완료
- **크롬(Chrome) 웹 앱 빌드 및 구동 성공**: 
  - 터미널에서 `cd smart_alarm_app` 후 `flutter clean`, `flutter pub get`, `flutter run -d chrome` 과정을 거쳐 리얼 산불 4분할 AI 비전 분석 관제 대시보드 화면 정상 출력 확인 완료.

---

## 🛠️ 내일(다음 작업) 이어서 할 일
1. **FastAPI 백엔드(`backend/`) 연동**: 
   - WebSocket 및 FCM(Firebase Cloud Messaging) 기반 실시간 알림 푸시 파이프라인 연결 검증.
2. **PC 대시보드 ➔ 모바일 앱 통합 연동 테스트**: 
   - `main_dashboard.py`에서 비상 상황 감지(F키 등) 시 Flutter 모바일 앱 화면이 실시간 RED 경보로 전환되는지 최종 시연 검증.

> **⚠️ 개발 주의사항 (OneDrive 사용 지양)**
> - 플러터 빌드 캐시 및 가상환경(`.venv`) 파일 충돌 방지를 위해 **원드라이브(OneDrive) 실시간 동기화 폴더 내 직접 작업은 피하고, 소스코드는 Git/원격(Remote) 환경을 통해 관리**할 것.