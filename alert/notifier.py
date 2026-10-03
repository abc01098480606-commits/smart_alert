import os
import requests
import cv2
import time

class TelegramNotifier:
    # 그룹방 Chat ID(-5220330330)를 기본값으로 적용
    def __init__(self, bot_token="8788536565:AAFDnkd9mgC_lXFhCOpwp1a2DXbP8Dms8zQ", chat_id="-5220330330"):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{self.bot_token}"

    def send_text(self, message):
        """긴급 경보 텍스트 메시지 전송 (소리 알림 강제 실행)"""
        url = f"{self.base_url}/sendMessage"
        data = {
            "chat_id": self.chat_id,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": False,  # 지도 링크 미리보기 허용
            "disable_notification": False
        }
        try:
            requests.post(url, data=data, timeout=5)
            print("📱 [텔레그램] 브로셔 스타일 긴급 경보 메시지 발송 완료")
        except Exception as e:
            print(f"❌ 텔레그램 메시지 전송 실패: {e}")

    def send_photo_with_overlay(self, frame, telemetry, step_num):
        """GPS 메타데이터 자막 각인 후 현장 스냅샷 전송"""
        if frame is None:
            return

        img = frame.copy()
        h, w, _ = img.shape
        
        # OSD 오버레이 자막 배경 (검은색 바)
        cv2.rectangle(img, (0, h - 65), (w, h), (0, 0, 0), -1)
        
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
        lat = telemetry.get('lat', 0)
        lon = telemetry.get('lon', 0)
        alt = telemetry.get('alt', 0)
        
        text_line1 = f"CRITICAL SNAPSHOT #{step_num} | TIME: {timestamp}"
        text_line2 = f"LAT: {lat:.7f} | LON: {lon:.7f} | ALT: {alt:.1f}m"
        
        cv2.putText(img, text_line1, (10, h - 38), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)
        cv2.putText(img, text_line2, (10, h - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

        # 캡처 저장 후 전송
        os.makedirs("captures", exist_ok=True)
        file_path = f"captures/snapshot_{step_num}.jpg"
        cv2.imwrite(file_path, img)

        map_url = f"https://maps.google.com/?q={lat},{lon}"

        url = f"{self.base_url}/sendPhoto"
        caption = f"📸 **[산불 현장 스냅샷 #{step_num}/4]** (+{step_num*5}초 갱신)\n" \
                  f"⏱ **캡처시각:** `{timestamp}`\n" \
                  f"📍 **위치:** [구글지도 현장위치 열기]({map_url})\n" \
                  f"🚁 **드론고도:** `{alt:.1f} m`"
        
        try:
            with open(file_path, 'rb') as photo:
                requests.post(url, data={
                    "chat_id": self.chat_id, 
                    "caption": caption, 
                    "parse_mode": "Markdown", 
                    "disable_notification": False
                }, files={"photo": photo}, timeout=10)
            print(f"📱 그룹방으로 스냅샷 #{step_num} (+{step_num*5}s) 전송 성공!")
        except Exception as e:
            print(f"❌ 스냅샷 전송 실패: {e}")