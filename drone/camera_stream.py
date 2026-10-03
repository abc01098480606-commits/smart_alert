import os
import cv2
import numpy as np
import threading
import time
import pygame

class CameraStream(threading.Thread):
    def __init__(self, fire_src="drone/fire_Movie.mp4", model_path="yolov8n.pt"):
        super().__init__()
        self.fire_src = fire_src
        self.running = True
        self.daemon = True
        self.fire_mode = False  # False: 평시 정찰 비행, True: 화재 감지 영상 출력
        self.cap = None
        self.frame = None
        self.fire_detected = False

    def toggle_fire_mode(self, state=None):
        """화재 감지 모드 토글 (평시 정찰 ↔ 화재 현장 영상)"""
        if state is None:
            self.fire_mode = not self.fire_mode
        else:
            self.fire_mode = state

        if self.fire_mode:
            # 화재 영상 로드
            if self.cap is None or not self.cap.isOpened():
                self.cap = cv2.VideoCapture(self.fire_src)
                print(f"🔥 [비전] 화재 현장 스트림 전환: {self.fire_src}")
        else:
            # 평시 모드로 전환 시 비디오 캡처 해제
            if self.cap is not None and self.cap.isOpened():
                self.cap.release()
                self.cap = None
            self.fire_detected = False
            print("🚁 [비전] 평시 정찰 비행 모드 전환")

    def run(self):
        while self.running:
            if self.fire_mode and self.cap is not None:
                ret, frame = self.cap.read()
                # 영상 무한 루프
                if not ret:
                    self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    time.sleep(0.03)
                    continue

                # 🔥 HSV 기반 화재 검출 및 Bounding Box 생성
                hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
                lower_fire = np.array([0, 120, 180])
                upper_fire = np.array([25, 255, 255])
                
                mask = cv2.inRange(hsv, lower_fire, upper_fire)
                contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

                fire_found = False
                for contour in contours:
                    if cv2.contourArea(contour) > 300:
                        x, y, w, h = cv2.boundingRect(contour)
                        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 0, 255), 2)
                        cv2.putText(frame, "FIRE DETECTED", (x, y - 8), 
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)
                        fire_found = True

                self.fire_detected = fire_found
                self.frame = frame
            else:
                # 평시 정찰 대기 화면 (검은 배경)
                self.frame = None
                self.fire_detected = False

            time.sleep(0.03)

    def get_pygame_surface(self, target_size=(840, 630)):
        if not self.fire_mode or self.frame is None:
            return None
        
        rgb_frame = cv2.cvtColor(self.frame, cv2.COLOR_BGR2RGB)
        resized_frame = cv2.resize(rgb_frame, target_size)
        height, width, _ = resized_frame.shape
        return pygame.image.frombuffer(resized_frame.tobytes(), (width, height), "RGB")

    def stop(self):
        self.running = False
        if self.cap is not None and self.cap.isOpened():
            self.cap.release()