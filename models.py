from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship, declarative_base
from datetime import datetime

Base = declarative_base()

# 1. Tabela de Usuários (Login)
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True) # CPF ou Email
    hashed_password = Column(String)
    role = Column(String) # "VICTIM" ou "AGENT"
    full_name = Column(String)

    # Relacionamentos
    incidents = relationship("Incident", back_populates="victim")

# 2. Tabela de Ocorrências
class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id")) # Link com a tabela Users
    status = Column(String, default="OPEN")
    latitude = Column(Float)
    longitude = Column(Float)
    created_at = Column(String, default=lambda: datetime.now().strftime("%d/%m/%Y às %H:%M"))

    victim = relationship("User", back_populates="incidents")
    messages = relationship("ChatMessage", back_populates="incident")

# 3. Tabela de Chat
class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey("incidents.id"))
    sender_name = Column(String)
    content = Column(String)
    timestamp = Column(String)

    incident = relationship("Incident", back_populates="messages")