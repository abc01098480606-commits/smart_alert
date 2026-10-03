from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import random

app = FastAPI()

# CORS 설정 (프론트엔드 통신 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 임시 메모리 DB (대원 정보 저장용)
users_db = {}
otp_db = {}

class RegisterModel(BaseModel):
    email: str
    password: str
    name: str

class LoginModel(BaseModel):
    email: str
    password: str

class OtpModel(BaseModel):
    email: str
    otp: str

@app.post("/api/register")
async def register(data: RegisterModel):
    if data.email in users_db:
        return {"success": False, "message": "이미 등록된 이메일입니다."}
    
    users_db[data.email] = {
        "password": data.password,
        "name": data.name
    }
    print(f"[대원 등록 완료] 이메일: {data.email}, 이름: {data.name}")
    return {"success": True, "message": "대원 등록 성공"}

@app.post("/api/login")
async def login(data: LoginModel):
    if data.email not in users_db:
        raise HTTPException(status_code=400, detail="등록되지 않은 이메일입니다.")
    
    if users_db[data.email]["password"] != data.password:
        raise HTTPException(status_code=400, detail="비밀번호가 일치하지 않습니다.")
    
    # 6자리 랜덤 OTP 생성 후 콘솔에 출력 (시연용으로 123456도 안내)
    generated_otp = str(random.randint(100000, 999999))
    otp_db[data.email] = generated_otp
    
    print("=" * 50)
    print(f"🚨 [OTP 발송] 대원 이메일: {data.email}")
    print(f"🔑 발송된 인증번호: {generated_otp}")
    print(f"✨ 시연용 고정 OTP: 123456 (언제든 사용 가능)")
    print("=" * 50)
    
    return {"success": True, "message": "OTP가 전송되었습니다.", "otp_hint": generated_otp}

@app.post("/api/verify-otp")
async def verify_otp(data: OtpModel):
    # 🔥 시연용 고정 OTP (123456) 무조건 통과 처리!
    if data.otp == "123456":
        print(f"[OTP 인증 성공] 시연용 고정 번호(123456)로 입장 - 대원: {data.email}")
        return {"success": True, "message": "OTP 인증 성공"}
    
    # 실제 발급된 OTP 번호와 비교
    stored_otp = otp_db.get(data.email)
    if stored_otp and data.otp == stored_otp:
        print(f"[OTP 인증 성공] 대원: {data.email}")
        return {"success": True, "message": "OTP 인증 성공"}
    
    raise HTTPException(status_code=400, detail="인증번호가 올바르지 않습니다.")

@app.get("/")
async def root():
    return {"message": "Smart Alert VTOL Backend is running!"}