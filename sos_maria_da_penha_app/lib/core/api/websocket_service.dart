import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  // Use 10.0.2.2 para emulador Android ou seu IP local (ex: 192.168.1.X) para celular físico
  final String _url = 'ws://192.168.18.8/ws/monitor'; 
  
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect() {
    try {
      print("Conectando ao WebSocket do Agente...");
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _controller.add(data);
          print("Agente recebeu: $data");
        },
        onError: (error) => print("Erro WS: $error"),
        onDone: () => print("WS Fechado"),
      );
    } catch (e) {
      print("Erro conexão: $e");
    }
  }
  

  // ADICIONE ESTA FUNÇÃO: Envia qualquer JSON para o Python
  void sendMessage(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    } else {
      print("Erro: WebSocket desconectado, tentando reconectar...");
      connect(); // Tenta reconectar se caiu
      Future.delayed(const Duration(seconds: 1), () {
         if (_channel != null) _channel!.sink.add(jsonEncode(data));
      });
    }
  }

  // ... restante do código ...

  // Função para o Agente dizer "Estou indo!"
  void sendStatusUpdate(int incidentId, String status) {
    if (_channel != null) {
      final payload = jsonEncode({
        "type": "STATUS_UPDATE",
        "incident_id": incidentId,
        "new_status": status
      });
      _channel!.sink.add(payload);
    }
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}