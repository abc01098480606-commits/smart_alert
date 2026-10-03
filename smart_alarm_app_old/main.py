import asyncio
import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Smart Alert VTOL Control Backend")

# CORS 설정 (Flutter Web 통신 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 실시간 관제 웹소켓 연결 관리자
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"🟢 [연결 성공] 관제 Flutter 클라이언트가 접속했습니다! (현재 접속 수: {len(self.active_connections)}대)")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            print("🔴 [연결 해제] 관제 클라이언트 접속이 종료되었습니다.")

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            await connection.send_text(json.dumps(message))

manager = ConnectionManager()

# Flutter앱이 실시간 신호를 수신하는 웹소켓 엔드포인트
@app.websocket("/ws/alerts")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            print(f"📩 [메시지 수신]: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# 🚨 외부 드론/센서에서 비상 경보 발송 시 호출하는 API
@app.post("/api/trigger-alert")
async def trigger_alert(payload: dict):
    alert_event = {
        "event": "EMERGENCY_ALERT",
        "title": payload.get("title", "AI VTOL 산불 조기감지"),
        "timestamp": payload.get("timestamp", "2026.09.20 / 19:10:00"),
        "lat": payload.get("lat", 37.7785),
        "lng": payload.get("lng", 126.6922),
        "gps": payload.get("gps", "37.7785, 126.6922"),
        "image_url": payload.get("image_url", "https://picsum.photos/800/450")
    }
    await manager.broadcast(alert_event)
    print(f"🚨 [비상 경보 브로드캐스트 전송 완료]: {alert_event['title']}")
    return {"status": "success", "sent_data": alert_event}

if __name__ == "__main__":
    import uvicorn
    print("🚀 Smart Alert 백엔드 서버를 시작합니다 (port: 8000)...")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)