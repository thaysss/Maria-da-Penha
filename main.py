from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status, File, UploadFile
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from sqlalchemy import create_engine, desc
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
import shutil
import os
import uuid
import math # <--- IMPORTANTE PARA CÁLCULO DE DISTÂNCIA

# Importando modelos
from models import Base, Incident, ChatMessage, User

# --- CONFIGURAÇÃO DE SEGURANÇA ---
SECRET_KEY = "segredo_super_secreto_da_guarda"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- BANCO DE DADOS ---
SQLALCHEMY_DATABASE_URL = "sqlite:///./banco_de_dados.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="SOS Guarda Municipal API")

# Configurações de Pastas e CORS
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

# --- FUNÇÕES ÚTEIS ---
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# --- SISTEMA DE DISTÂNCIA E WEBSOCKET ---

# Memória RAM para guardar onde cada agente está agora
# Ex: {1: {"lat": -10.0, "lng": -37.0, "name": "Silva"}}
active_agents = {}
active_victims = {} # Guarda: {id: {lat, lng, name}}

def calculate_distance(lat1, lon1, lat2, lon2):
    # Fórmula de Haversine para calcular distância em KM
    R = 6371 
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dlon/2) * math.sin(dlon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c 

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections[:]:
            try:
                await connection.send_json(message)
            except:
                self.disconnect(connection)

manager = ConnectionManager()

# --- SCHEMAS ---
class UserCreate(BaseModel):
    username: str
    password: str
    role: str 
    full_name: str

class Token(BaseModel):
    access_token: str
    token_type: str
    role: str
    user_id: int
    name: str

class PanicAlertSchema(BaseModel):
    user_id: int
    latitude: float
    longitude: float

class IncidentCloseSchema(BaseModel):
    final_report: str

# --- ROTAS ---

@app.post("/register", status_code=201)
def register(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Usuário já existe")
    hashed_password = get_password_hash(user.password)
    new_user = User(username=user.username, hashed_password=hashed_password, role=user.role, full_name=user.full_name)
    db.add(new_user)
    db.commit()
    return {"msg": "Usuário criado"}

@app.post("/token", response_model=Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Erro login")
    access_token = create_access_token(data={"sub": user.username, "role": user.role, "id": user.id})
    return {"access_token": access_token, "token_type": "bearer", "role": user.role, "user_id": user.id, "name": user.full_name}

@app.post("/api/panic", status_code=201)
async def create_panic_alert(alert: PanicAlertSchema, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == alert.user_id).first()
    if not user: raise HTTPException(status_code=404)

    new_incident = Incident(user_id=alert.user_id, latitude=alert.latitude, longitude=alert.longitude, status="OPEN")
    db.add(new_incident)
    db.commit()
    db.refresh(new_incident)

    alert_data = {
        "type": "NEW_PANIC_ALERT",
        "incident_id": new_incident.id,
        "victim_id": new_incident.user_id,
        "victim_name": user.full_name,
        "location": {"lat": new_incident.latitude, "lng": new_incident.longitude},
        "time": new_incident.created_at,
        "message": f"ALERTA: {user.full_name} precisa de ajuda!"
    }
    await manager.broadcast(alert_data)
    return {"status": "received", "incident_id": new_incident.id}
# ... (outros imports)

# ROTA PARA O AGENTE (VÊ TUDO)
@app.get("/api/incidents")
def get_all_incidents(db: Session = Depends(get_db)):
    # Pega os últimos 50 chamados do sistema inteiro
    incidents = db.query(Incident).order_by(desc(Incident.id)).limit(50).all()
    
    result = []
    for inc in incidents:
        # Busca nome da vítima
        victim_name = "Desconhecido"
        if inc.victim:
             victim_name = inc.victim.full_name

        result.append({
            "id": inc.id,
            "victim_name": victim_name, # Manda o nome para o agente saber quem foi
            "status": inc.status,
            "date": inc.created_at,
            "location": {"lat": inc.latitude, "lng": inc.longitude}
        })
    return result

@app.get("/api/incidents/{incident_id}/chat")
def get_chat_history(incident_id: int, db: Session = Depends(get_db)):
    messages = db.query(ChatMessage).filter(ChatMessage.incident_id == incident_id).all()
    return [{"sender_name": m.sender_name, "content": m.content, "timestamp": m.timestamp} for m in messages]

@app.put("/api/incidents/{incident_id}/close")
async def close_incident(incident_id: int, data: IncidentCloseSchema, db: Session = Depends(get_db)):
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident: raise HTTPException(status_code=404)
    incident.status = "CLOSED"
    db.commit()
    
    await manager.broadcast({
        "type": "CASE_CLOSED",
        "incident_id": incident_id,
        "final_report": data.final_report
    })
    return {"status": "closed"}

@app.post("/api/upload")
async def upload_evidence(file: UploadFile = File(...)):
    _, file_extension = os.path.splitext(file.filename)
    if not file_extension: file_extension = ".png"
    safe_filename = f"{uuid.uuid4()}{file_extension}"
    with open(f"uploads/{safe_filename}", "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"url": f"http://127.0.0.1:8000/uploads/{safe_filename}"}



@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard():
    with open("templates/dashboard.html", "r", encoding="utf-8") as f:
        return f.read()



@app.websocket("/ws/monitor")
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
    await manager.connect(websocket)
    current_user_id = None
    user_role = None # Para saber se removemos de agents ou victims ao sair
    
    try:
        while True:
            data = await websocket.receive_json()
            
            # 1. RASTREAMENTO DE AGENTE (JÁ EXISTIA)
            if data.get("type") == "AGENT_LOCATION_UPDATE":
                current_user_id = data["user_id"]
                user_role = "AGENT"
                active_agents[current_user_id] = {
                    "lat": data["lat"], 
                    "lng": data["lng"], 
                    "name": data["name"]
                }
                await manager.broadcast({
                    "type": "AGENT_MOVED",
                    "agent_id": current_user_id,
                    "location": {"lat": data["lat"], "lng": data["lng"]},
                    "name": data["name"]
                })

            # 2. RASTREAMENTO DE VÍTIMA (NOVO)
            elif data.get("type") == "VICTIM_LOCATION_UPDATE":
                current_user_id = data["user_id"]
                user_role = "VICTIM"
                active_victims[current_user_id] = {
                    "lat": data["lat"], 
                    "lng": data["lng"], 
                    "name": data["name"]
                }
                # Avisa o painel para desenhar a vítima (ícone de pessoa)
                await manager.broadcast({
                    "type": "VICTIM_MOVED",
                    "victim_id": current_user_id,
                    "location": {"lat": data["lat"], "lng": data["lng"]},
                    "name": data["name"]
                })

            # 3. DESPACHO (MANTENHA IGUAL)
            elif data.get("type") == "DISPATCH_NEAREST":
                # ... (código anterior do despacho mantém igual) ...
                # (Copie a lógica do passo anterior aqui para não perder)
                victim_lat = data["location"]["lat"]
                victim_lng = data["location"]["lng"]
                nearest_agent = None
                min_dist = float("inf")
                
                for agent_id, agent_data in active_agents.items():
                    dist = calculate_distance(victim_lat, victim_lng, agent_data["lat"], agent_data["lng"])
                    if dist < min_dist:
                        min_dist = dist
                        nearest_agent = agent_data
                
                if nearest_agent:
                    await manager.broadcast({
                        "type": "NEW_PANIC_ALERT",
                        "incident_id": data["incident_id"],
                        "victim_name": data["victim_name"],
                        "location": data["location"],
                        "target_agent_name": nearest_agent["name"],
                        "message": "VOCÊ É A VIATURA MAIS PRÓXIMA!"
                    })
                    await manager.broadcast({
                        "type": "DISPATCH_CONFIRMED",
                        "agent_name": nearest_agent["name"],
                        "distance": round(min_dist, 2)
                    })
                else:
                    await manager.broadcast({"type": "NO_AGENTS_AVAILABLE"})

            # ... (MANTENHA SEND_CHAT_MESSAGE e STATUS_UPDATE IGUAIS) ...
            elif data.get("type") == "SEND_CHAT_MESSAGE":
                # ... (Lógica de chat igual) ...
                session = SessionLocal()
                msg_time = datetime.now().strftime("%H:%M")
                new_msg = ChatMessage(incident_id=data["incident_id"], sender_name=data["sender_name"], content=data["content"], timestamp=msg_time)
                session.add(new_msg)
                session.commit()
                session.close()
                data["timestamp"] = msg_time
                data["type"] = "NEW_CHAT_MESSAGE"
                await manager.broadcast(data)
            elif data.get("type") == "STATUS_UPDATE":
                await manager.broadcast(data)

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        # Remove da lista correta ao desconectar
        if current_user_id:
            if user_role == "AGENT" and current_user_id in active_agents:
                del active_agents[current_user_id]
            elif user_role == "VICTIM" and current_user_id in active_victims:
                del active_victims[current_user_id]