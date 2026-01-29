from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends
from fastapi.middleware.cors import CORSMiddleware # <--- IMPORTANTE
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
from datetime import datetime
from models import Incident, IncidentStatus, User, Base

app = FastAPI(title="SOS Guarda Municipal API")

# --- NOVO: Configuração de CORS para aceitar o App Web ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Aceita conexões de qualquer origem (App Web, Mobile, etc)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Dependência de Banco de Dados ---
def get_db():
    try:
        yield "fake_db_session"
    finally:
        pass

# --- Gerenciador de Real-Time ---
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

# --- Modelos ---
class PanicAlertSchema(BaseModel):
    user_id: int
    latitude: float
    longitude: float

# --- Endpoints ---
@app.post("/api/panic", status_code=201)
async def create_panic_alert(alert: PanicAlertSchema, db: Session = Depends(get_db)):
    fake_incident_id = 101 
    alert_data = {
        "type": "NEW_PANIC_ALERT",
        "incident_id": fake_incident_id,
        "victim_id": alert.user_id,
        "location": {"lat": alert.latitude, "lng": alert.longitude},
        "time": str(datetime.now()),
        "message": "URGENTE: Botão de Pânico acionado!"
    }
    await manager.broadcast(alert_data)
    return {"status": "received", "incident_id": fake_incident_id}



@app.websocket("/ws/monitor")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # 1. Recebe dados do App (Vítima ou Agente)
            data = await websocket.receive_json()
            
            # 2. Verifica se é uma Mensagem de Chat
            if data.get("type") == "SEND_CHAT_MESSAGE":
                # Repassa a mensagem para todos (Broadcast)
                # O App vai filtrar se a mensagem é para ele ou não
                await manager.broadcast({
                    "type": "NEW_CHAT_MESSAGE",
                    "incident_id": data["incident_id"],
                    "sender_name": data["sender_name"], # Ex: "Maria" ou "Agente Silva"
                    "content": data["content"],
                    "timestamp": str(datetime.now().strftime("%H:%M"))
                })
                
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        print(f"Erro no WebSocket: {e}")
        manager.disconnect(websocket)

@app.post("/api/incidents/{incident_id}/status")
async def update_status(incident_id: int, status: str):
    await manager.broadcast({
        "type": "STATUS_UPDATE",
        "incident_id": incident_id,
        "new_status": status,
    })
    return {"status": "updated"}