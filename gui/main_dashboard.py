import os
import sys
import time
import threading
import numpy as np
import pygame

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from drone.mavlink_listener import MAVLinkListener
from drone.camera_stream import CameraStream
from alert.notifier import TelegramNotifier

pygame.init()
WIDTH, HEIGHT = 1280, 720
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Smart Alert AI VTOL - 산불 조기감지 통합 관제 대시보드 (v1.2)")
clock = pygame.time.Clock()

# --- 🔊 실시간 경고음(Siren) 생성 모듈 ---
def generate_siren_sound(frequency1=800, frequency2=1200, duration=1.0, sample_rate=22050):
    """Pygame Mixer용 비상 사이렌 오디오 생성"""
    n_samples = int(sample_rate * duration)
    half_samples = n_samples // 2
    
    t1 = np.linspace(0, duration/2, half_samples, False)
    t2 = np.linspace(0, duration/2, half_samples, False)
    
    wave1 = np.sin(2 * np.pi * frequency1 * t1)
    wave2 = np.sin(2 * np.pi * frequency2 * t2)
    
    wave = np.concatenate((wave1, wave2))
    audio = (wave * 32767).astype(np.int16)
    
    # 스테레오 변환
    stereo_audio = np.repeat(audio[:, np.newaxis], 2, axis=1)
    return pygame.sndarray.make_sound(stereo_audio)

# Mixer 초기화 및 사이렌 생성
try:
    pygame.mixer.init(frequency=22050, size=-16, channels=2)
    siren_sound = generate_siren_sound()
except Exception as e:
    print(f"⚠️ 오디오 장치 초기화 실패: {e}")
    siren_sound = None

BG_COLOR = (20, 24, 33)
PANEL_BG = (32, 38, 50)
ACCENT_BLUE = (0, 180, 216)
ALERT_RED = (230, 57, 70)
GREEN = (42, 157, 143)
TEXT_COLOR = (240, 240, 240)
GRAY = (120, 120, 120)

font_title = pygame.font.SysFont("malgungothic", 22, bold=True)
font_large = pygame.font.SysFont("malgungothic", 18, bold=True)
font_small = pygame.font.SysFont("malgungothic", 14)

# MAVLink 수신 스레드
drone_listener = MAVLinkListener('udpin:0.0.0.0:14553')
drone_listener.start()

# 비디오 및 카메라 스트림
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
video_path = os.path.join(BASE_DIR, "drone", "fire_Movie.mp4")
camera_stream = CameraStream(fire_src=video_path, model_path="yolov8n.pt")
camera_stream.start()

# 텔레그램 알림 모듈 (Smart Alert Test 그룹방 ID 적용)
notifier = TelegramNotifier(
    bot_token="8788536565:AAFDnkd9mgC_lXFhCOpwp1a2DXbP8Dms8zQ",
    chat_id="-5220330330"
)

running = True
low_battery_triggered = False

log_messages = [
    f"[{time.strftime('%H:%M:%S')}] 시스템 가동 준비 완료",
    f"[{time.strftime('%H:%M:%S')}] MAVLink 14553 포트 바인딩 완료",
    f"[{time.strftime('%H:%M:%S')}] Smart Alert Test 그룹방 연동 완료 (Chat ID: -5220330330)"
]

def add_log(msg):
    log_messages.append(f"[{time.strftime('%H:%M:%S')}] {msg}")
    if len(log_messages) > 10:
        log_messages.pop(0)

# 5초 간격 사진 4장 모바일 푸시 전송 백그라운드 시퀀스 (브로셔 스타일 포맷 반영)
def trigger_mobile_alert_sequence(stream_obj, tele_data):
    def run_sequence():
        try:
            lat = tele_data.get('lat', 0)
            lon = tele_data.get('lon', 0)
            alt = tele_data.get('alt', 0)
            event_time = time.strftime('%Y.%m.%d / %H:%M:%S')
            
            # 지도 URL (구글 맵 / 카카오 맵)
            google_map_url = f"https://maps.google.com/?q={lat},{lon}"
            kakao_map_url = f"https://map.kakao.com/link/map/산불발생지점,{lat},{lon}"

            # Smart Alarm 브로셔 스타일 포맷팅
            msg = f"🚨 **[Smart Alarm] 위급상황! 경보발생!** 🚨\n\n" \
                  f"🔥 **경보유형:** AI VTOL 산불 조기감지\n" \
                  f"⏱ **발생시각:** `{event_time}`\n" \
                  f"📍 **GPS 좌표:** `{lat:.7f}, {lon:.7f}`\n" \
                  f"🚁 **비행고도:** `{alt:.1f} m`\n\n" \
                  f"🗺 **실시간 지도 확인:**\n" \
                  f"• [Google Maps로 위치 확인]({google_map_url})\n" \
                  f"• [Kakao Map으로 위치 확인]({kakao_map_url})\n\n" \
                  f"⚠️ *현장 OSD 자막 스냅샷 4장이 5초 간격으로 순차 전송됩니다.*"

            notifier.send_text(msg)

            for i in range(1, 5):
                time.sleep(5)
                if stream_obj.fire_mode:
                    current_frame = stream_obj.frame
                    notifier.send_photo_with_overlay(current_frame, tele_data, step_num=i)
        except Exception as e:
            print(f"❌ [모바일 알림 시퀀스 오류]: {e}")

    threading.Thread(target=run_sequence, daemon=True).start()

while running:
    dt = clock.tick(30)
    telemetry = drone_listener.data

    # --- 1. 이벤트 처리 ---
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_f:
                camera_stream.toggle_fire_mode()
                if camera_stream.fire_mode:
                    add_log("🔥 [AI 탐지] 화재 발생! 스마트폰 푸시 및 비상 경고음 발동")
                    if siren_sound:
                        siren_sound.play(loops=-1) # 사이렌 경고음 무한 반복 재생
                    trigger_mobile_alert_sequence(camera_stream, telemetry)
                else:
                    add_log("🚁 [비전] 평시 정찰 비행 상태 복귀")
                    if siren_sound:
                        siren_sound.stop() # 평시 복귀 시 사이렌 정지
            elif event.key == pygame.K_b:
                drone_listener.set_battery_override(15)
                add_log("⚠️ [테스트] 배터리 잔량을 15%로 강제 차감했습니다.")
            elif event.key == pygame.K_ESCAPE:
                running = False

    # --- 2. Low Battery 자율 RTL 복귀 트리거 감지 ---
    battery_level = telemetry.get('battery', 100)
    if battery_level <= 20 and not low_battery_triggered:
        low_battery_triggered = True
        add_log(f"⚠️ [비상] 배터리 부족 ({battery_level}%)! 충전 스테이션으로 자동 복귀(RTL)")
        
        if hasattr(drone_listener, 'master') and drone_listener.master:
            try:
                drone_listener.master.set_mode('RTL')
                add_log("🔄 MAVLink: RTL 모드 송신 완료")
            except Exception as e:
                add_log(f"❌ RTL 송신 실패: {e}")

    # --- 3. 화면 그리기 ---
    screen.fill(BG_COLOR)

    # 3-1. 상단 헤더
    pygame.draw.rect(screen, PANEL_BG, (10, 10, WIDTH - 20, 50), border_radius=8)
    title_txt = font_title.render("🔥 Smart Alert: AI VTOL 산불 감지 관제 시스템", True, TEXT_COLOR)
    screen.blit(title_txt, (25, 20))

    status_str = "CONNECTED" if telemetry["connected"] else "DISCONNECTED"
    status_color = GREEN if telemetry["connected"] else ALERT_RED
    status_txt = font_large.render(f"드론 통신: {status_str}", True, status_color)
    screen.blit(status_txt, (WIDTH - 220, 22))

    # 3-2. 메인 카메라 뷰
    cam_rect = pygame.Rect(10, 70, 840, 630)
    cam_surface = camera_stream.get_pygame_surface(target_size=(840, 630))

    if cam_surface is not None:
        screen.blit(cam_surface, (10, 70))
    else:
        pygame.draw.rect(screen, (10, 10, 10), cam_rect, border_radius=8)
        cam_tag = font_small.render("SCANNING FOR FIRE / RECONNAISSANCE PATROL...", True, GREEN)
        screen.blit(cam_tag, (30, 90))

    if camera_stream.fire_mode:
        pygame.draw.rect(screen, ALERT_RED, cam_rect, width=4, border_radius=8)
        alert_tag = font_large.render("⚠️ FIRE DETECTED! (Siren & Mobile Alert Active)", True, ALERT_RED)
        screen.blit(alert_tag, (30, 90))

    # OSD 텍스트
    osd_lines = [
        f"LAT: {telemetry['lat']:.7f} | LON: {telemetry['lon']:.7f}",
        f"ALT: {telemetry['alt']:.1f} m | HEADING: {telemetry['heading']}°",
        f"MODE: {telemetry['mode']} | ARMED: {telemetry['armed']} | BAT: {telemetry['battery']}%"
    ]
    for idx, line in enumerate(osd_lines):
        txt_surf = font_small.render(line, True, (0, 255, 200))
        screen.blit(txt_surf, (25, 630 + (idx * 20)))

    # 3-3. 우측 정보 패널
    panel_x = 860
    panel_w = WIDTH - panel_x - 10

    # 비행 메타데이터
    pygame.draw.rect(screen, PANEL_BG, (panel_x, 70, panel_w, 280), border_radius=8)
    screen.blit(font_large.render("🚁 비행 메타데이터", True, ACCENT_BLUE), (panel_x + 15, 80))

    data_labels = [
        ("위도 (Latitude)", f"{telemetry['lat']:.7f}"),
        ("경도 (Longitude)", f"{telemetry['lon']:.7f}"),
        ("고도 (Altitude)", f"{telemetry['alt']:.2f} m"),
        ("방위각 (Heading)", f"{telemetry['heading']}°"),
        ("비행 모드", f"{telemetry['mode']}"),
        ("배터리 잔량", f"{telemetry['battery']}%")
    ]

    for idx, (label, val) in enumerate(data_labels):
        lbl_s = font_small.render(f"• {label}:", True, TEXT_COLOR)
        val_s = font_small.render(val, True, (255, 215, 0))
        screen.blit(lbl_s, (panel_x + 20, 115 + (idx * 26)))
        screen.blit(val_s, (panel_x + 160, 115 + (idx * 26)))

    # 관제 및 이벤트 로그
    pygame.draw.rect(screen, PANEL_BG, (panel_x, 360, panel_w, 240), border_radius=8)
    screen.blit(font_large.render("📋 관제 및 이벤트 로그", True, ACCENT_BLUE), (panel_x + 15, 370))

    for idx, log in enumerate(log_messages[-6:]):
        if "🔥" in log or "⚠️" in log:
            log_color = ALERT_RED
        elif "🔄" in log:
            log_color = ACCENT_BLUE
        else:
            log_color = TEXT_COLOR
            
        log_s = font_small.render(log, True, log_color)
        screen.blit(log_s, (panel_x + 15, 405 + (idx * 22)))

    # 하단 조작 가이드
    pygame.draw.rect(screen, PANEL_BG, (panel_x, 610, panel_w, 90), border_radius=8)
    screen.blit(font_small.render("[ F ] : 화재 발견 ➔ 사이렌 & 사진 전송", True, (255, 180, 0)), (panel_x + 15, 620))
    screen.blit(font_small.render("[ B ] : Low Battery (15%) 강제 복귀 테스트", True, ALERT_RED), (panel_x + 15, 642))
    screen.blit(font_small.render("[ ESC ]: 대시보드 종료", True, GRAY), (panel_x + 15, 664))

    pygame.display.flip()

# 종료
if siren_sound:
    siren_sound.stop()
camera_stream.stop()
drone_listener.stop()
pygame.quit()
sys.exit()