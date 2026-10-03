import threading
import time
from pymavlink import mavutil

class MAVLinkListener(threading.Thread):
    def __init__(self, connection_str='udpin:0.0.0.0:14553'):
        super().__init__()
        self.connection_str = connection_str
        self.running = True
        self.daemon = True
        self.master = None  # MAVLink 명령 송신용 객체
        self.override_battery = False  # B키 테스트용 배터리 고정 플래그
        self.data = {
            "connected": False,
            "lat": 0.0,
            "lon": 0.0,
            "alt": 0.0,
            "heading": 0,
            "mode": "UNKNOWN",
            "armed": False,
            "battery": 100,
            "last_update": 0
        }

    def run(self):
        print(f"📡 MAVLink 통신 대기 중: {self.connection_str}")
        try:
            self.master = mavutil.mavlink_connection(self.connection_str)
        except Exception as e:
            print(f"❌ MAVLink 바인딩 실패: {e}")
            return

        while self.running:
            msg = self.master.recv_match(blocking=True, timeout=1.0)
            if msg is None:
                if time.time() - self.data["last_update"] > 3.0:
                    self.data["connected"] = False
                continue

            self.data["connected"] = True
            self.data["last_update"] = time.time()
            msg_type = msg.get_type()

            if msg_type == 'GLOBAL_POSITION_INT':
                self.data["lat"] = msg.lat / 1e7
                self.data["lon"] = msg.lon / 1e7
                self.data["alt"] = msg.relative_alt / 1000.0
                self.data["heading"] = msg.hdg / 100.0
            elif msg_type == 'HEARTBEAT':
                self.data["armed"] = bool(msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED)
                self.data["mode"] = mavutil.mode_string_v10(msg)
            elif msg_type == 'SYS_STATUS':
                # 강제 차감 테스트 중이 아닐 때만 실제 배터리 수신
                if not self.override_battery:
                    self.data["battery"] = msg.battery_remaining if msg.battery_remaining != -1 else 100

    def set_battery_override(self, val):
        """B키 테스트용 배터리 수치 고정 메서드"""
        self.override_battery = True
        self.data["battery"] = val

    def stop(self):
        self.running = False