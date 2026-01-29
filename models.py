from enum import Enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Boolean, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

Base = declarative_base()

# Enums para padronizar status (Baseado no fluxo do SOS Agente/BackOffice)
class UserType(str, Enum):
    VICTIM = "victim"       # Usuária do App Maria da Penha
    AGENT = "agent"         # Guarda Municipal (App Agente)
    DISPATCHER = "admin"    # Operador do BackOffice
    CITIZEN = "citizen"     # Usuário do App Pânico Geral

class IncidentStatus(str, Enum):
    OPEN = "open"           # Botão pressionado, aguardando central
    DISPATCHED = "dispatched" # Central enviou viatura
    ON_SITE = "on_site"     # Agente chegou (Georreferenciado)
    RESOLVED = "resolved"   # Finalizado com relatório

class IncidentType(str, Enum):
    MARIA_DA_PENHA = "maria_da_penha"
    PANIC_BUTTON = "panic_general"
    HARASSMENT = "harassment"

# 1. Tabela de Usuários (Centraliza Vítimas, Agentes e Operadores)
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    cpf = Column(String, unique=True, index=True) # Importante para validação
    phone = Column(String)
    password_hash = Column(String) # Nunca salvar senha pura!
    user_type = Column(String, nullable=False) # Usa o Enum UserType
    
    # Dados específicos para Agentes (extraídos do FolderSOSAgente)
    badge_number = Column(String, nullable=True) # Matrícula funcional
    is_active_duty = Column(Boolean, default=False) # Se está em turno agora
    
    # Dados de Saúde/Emergência para Vítimas
    emergency_contact = Column(String, nullable=True)

# 2. Tabela de Viaturas (Gestão de Frota e Cautela)
class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, index=True)
    plate = Column(String, unique=True)
    model = Column(String)
    call_sign = Column(String) # Ex: "Viatura 05"
    is_active = Column(Boolean, default=True)
    
    # Relação: Qual agente está com a viatura agora? (Checklist/Cautela)
    current_driver_id = Column(Integer, ForeignKey("users.id"), nullable=True)

# 3. Tabela de Ocorrências (O evento central do sistema)
class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)
    victim_id = Column(Integer, ForeignKey("users.id"))
    
    # Tipo e Status
    incident_type = Column(String, default=IncidentType.PANIC_BUTTON)
    status = Column(String, default=IncidentStatus.OPEN)
    
    # Localização Inicial (Onde o botão foi apertado)
    latitude = Column(Float)
    longitude = Column(Float)
    address_text = Column(String, nullable=True) # Geocoding reverso
    
    created_at = Column(DateTime, default=datetime.utcnow)
    closed_at = Column(DateTime, nullable=True)

    # Quem atendeu?
    assigned_agent_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    assigned_vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)

    # Relacionamento para o Chat/Evidências
    evidences = relationship("IncidentEvidence", back_populates="incident")

# 4. Tabela de Evidências/Chat (Fotos, Vídeos, Mensagens)
class IncidentEvidence(Base):
    __tablename__ = "incident_evidences"

    id = Column(Integer, primary_key=True)
    incident_id = Column(Integer, ForeignKey("incidents.id"))
    uploader_id = Column(Integer, ForeignKey("users.id")) # Quem mandou? Vítima ou Agente?
    
    media_type = Column(String) # 'image', 'video', 'text'
    file_url = Column(String) # Link para o S3/Storage (Nunca salvar arquivo no banco!)
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    incident = relationship("Incident", back_populates="evidences")