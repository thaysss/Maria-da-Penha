import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  // 1. Singleton: Garante que só existe UMA conexão aberta no app inteiro
  static final WebSocketService _instance = WebSocketService._internal();
  
  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  WebSocketChannel? _channel;
  
  // 2. Broadcast: Permite que várias telas escutem ao mesmo tempo
  final StreamController<Map<String, dynamic>> _controller = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  // Ajuste o IP conforme necessário (127.0.0.1 para Linux/Web, 10.0.2.2 para Emulador Android)
  final String _url = 'ws://127.0.0.1:8000/ws/monitor';

  void connect() {
    // Se já estiver conectado, não faz nada
    if (_channel != null) return;

    try {
      print("Conectando ao WebSocket: $_url");
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      
      _channel!.stream.listen(
        (message) {
          // Quando chega mensagem, repassa para todos os ouvintes (Broadcast)
          final data = jsonDecode(message);
          _controller.add(data);
        },
        onError: (error) {
          print("Erro WS: $error");
          _reconnect();
        },
        onDone: () {
          print("Conexão WS fechada.");
          _channel = null; // Limpa para permitir reconexão
          _reconnect();
        },
      );
    } catch (e) {
      print("Erro ao conectar: $e");
      _reconnect();
    }
  }

  void _reconnect() {
    // Tenta reconectar após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (_channel == null) connect();
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      print("Tentando enviar mensagem sem conexão. Reconectando...");
      connect();
    }
  }

  void sendStatusUpdate(int incidentId, String status) {
    sendMessage({
      "type": "STATUS_UPDATE",
      "incident_id": incidentId,
      "new_status": status
    });
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}