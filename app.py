from flask import Flask, request, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity
from flask_socketio import SocketIO, emit
from datetime import datetime
from decimal import Decimal
from werkzeug.security import generate_password_hash, check_password_hash
import os
from dotenv import load_dotenv
import os


load_dotenv()

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_IDENTITY_CLAIM'] = 'sub'
app.config['JWT_VERIFY_SUB'] = False  # Aceita qualquer tipo





db = SQLAlchemy(app)
jwt = JWTManager(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# Models (como definido antes)
class UsuarioCidadao(db.Model):
    __tablename__ = 'usuarios_cidadao'  # Força nome exato
    id = db.Column(db.BigInteger, primary_key=True)  # BIGSERIAL = BigInteger
    nome = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    telefone = db.Column(db.String(20))
    criado_em = db.Column(db.DateTime)

class Agente(db.Model):
    __tablename__ = 'agentes'
    id = db.Column(db.BigInteger, primary_key=True)
    nome = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    telefone = db.Column(db.String(20))
    ativo = db.Column(db.Boolean, default=True)

class Ocorrencia(db.Model):
    __tablename__ = 'ocorrencias'
    id = db.Column(db.BigInteger, primary_key=True)
    cidadao_id = db.Column(db.BigInteger, db.ForeignKey('usuarios_cidadao.id'))
    agente_id = db.Column(db.BigInteger, db.ForeignKey('agentes.id'), nullable=True)
    titulo = db.Column(db.String(200))
    descricao = db.Column(db.Text)
    latitude = db.Column(db.Numeric(10,8))
    longitude = db.Column(db.Numeric(11,8))
    status = db.Column(db.String(30), default='nova')
    criado_em = db.Column(db.DateTime)
    atualizado_em = db.Column(db.DateTime)


from werkzeug.security import generate_password_hash, check_password_hash

# Tabela users para login (adicione no SQL depois)
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(100), unique=True)
    senha_hash = db.Column(db.String(200))
    tipo = db.Column(db.String(20))  # 'cidadao' ou 'agente'


@jwt.user_identity_loader
def user_identity_lookup(user):
    return str(user)  # Converte ID para string


# POST /register_cidadao
@app.route('/register_cidadao', methods=['POST'])
def register_cidadao():
    data = request.get_json()
    if UsuarioCidadao.query.filter_by(email=data['email']).first():
        return jsonify({'erro': 'Email existe'}), 400
    
    cidadao = UsuarioCidadao(nome=data['nome'], email=data['email'], telefone=data.get('telefone'))
    db.session.add(cidadao)
    db.session.commit()
    return jsonify({'msg': 'Cidadão criado', 'id': cidadao.id})

# POST /login_cidadao
@app.route('/login_cidadao', methods=['POST'])
def login_cidadao():
    data = request.get_json()
    cidadao = UsuarioCidadao.query.filter_by(email=data['email']).first()
    if cidadao:
        token = create_access_token(identity={'tipo': 'cidadao', 'id': cidadao.id})
        return jsonify({'token': token})
    return jsonify({'erro': 'Não encontrado'}), 401

@app.route('/ocorrencias', methods=['POST'])
@jwt_required()
def criar_ocorrencia():
    data = request.get_json()
    cidadao_id = get_jwt_identity()
    
    ocorrencia = Ocorrencia(
        cidadao_id=cidadao_id,
        titulo=data['titulo'],
        descricao=data['descricao'],
        latitude=Decimal(data['latitude']),
        longitude=Decimal(data['longitude'])
    )
    db.session.add(ocorrencia)
    db.session.commit()
    
    # Notifica painel via socket
    socketio.emit('nova_ocorrencia', {
        'id': ocorrencia.id,
        'titulo': ocorrencia.titulo,
        'latitude': str(ocorrencia.latitude),
        'longitude': str(ocorrencia.longitude)
    })
    
    return jsonify({'id': ocorrencia.id, 'status': 'criada'}), 201

# Rota painel: GET /ocorrencias
@app.route('/ocorrencias', methods=['GET'])
@jwt_required()
def listar_ocorrencias():
    ocorrencias = Ocorrencia.query.all()
    return jsonify([{
        'id': o.id,
        'titulo': o.titulo,
        'status': o.status,
        'cidadao_id': o.cidadao_id,
        'agente_id': o.agente_id,
        'latitude': str(o.latitude),
        'longitude': str(o.longitude)
    } for o in ocorrencias])

# Rota atribuir
@app.route('/ocorrencias/<int:id>/atribuir', methods=['PATCH'])
@jwt_required()
def atribuir_ocorrencia(id):
    data = request.get_json()
    ocorrencia = Ocorrencia.query.get_or_404(id)
    ocorrencia.agente_id = data['agente_id']
    ocorrencia.status = 'atribuida'
    db.session.commit()
    
    # Notifica agente
    socketio.emit('ocorrencia_atribuida', {
        'id': id,
        'agente_id': data['agente_id']
    }, room=f'agente_{data["agente_id"]}')
    
    return jsonify({'status': 'atribuida'})

# Socket events
@socketio.on('connect')
def handle_connect():
    agente_id = request.args.get('agente_id')
    if agente_id:
        emit('conectado', {'msg': 'Pronto para receber'})

from flask import render_template

@app.route('/')
def painel():
    return render_template('index.html')


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    socketio.run(app, debug=True)

