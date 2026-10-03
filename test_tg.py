import os
import requests
import cv2
import numpy as np

BOT_TOKEN = "8788536565:AAFDnkd9mgC_lXFhCOpwp1a2DXbP8Dms8zQ"
CHAT_ID = "7157915411"

print("📡 텔레그램 메세지 및 사진 전송 시도 중...")

# 1. 텍스트 메시지 테스트
url_msg = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
res_msg = requests.post(url_msg, data={"chat_id": CHAT_ID, "text": "🔥 [Smart Alert] 텔레그램 단독 테스트 성공!"})
print("메시지 전송 응답:", res_msg.json())

# 2. 이미지 파일 생성 및 사진 전송 테스트
os.makedirs("captures", exist_ok=True)
test_img_path = "captures/test_snapshot.jpg"

# [핵심 수정] 동영상 파일에서 진짜 첫 프레임 읽어오기
cap = cv2.VideoCapture("drone/fire_Movie.mp4")
success, dummy_frame = cap.read()
cap.release()

if success and dummy_frame is not None:
    cv2.imwrite(test_img_path, dummy_frame)
    print("성공: 실제 비디오 프레임 캡처 완료!")
else:
    # 비디오 로드가 실패할 경우 대비용 검은색 캔버스 이미지 생성
    black_img = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.putText(black_img, "TEST SNAPSHOT", (50, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    cv2.imwrite(test_img_path, black_img)
    print("경고: 비디오 로드 실패로 대체 이미지 생성됨")

# 3. 텔레그램으로 사진 전송
url_photo = f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto"
with open(test_img_path, "rb") as photo:
    res_photo = requests.post(url_photo, data={"chat_id": CHAT_ID, "caption": "📸 테스트 스냅샷 전송"}, files={"photo": photo})

print("사진 전송 응답:", res_photo.json())
