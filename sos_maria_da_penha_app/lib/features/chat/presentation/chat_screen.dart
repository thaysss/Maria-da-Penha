import 'package:flutter/material.dart';
import '../../../../core/api/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final int incidentId;
  final String userName; // Quem está enviando? (Vítima ou Agente)

  const ChatScreen({
    super.key, 
    required this.incidentId, 
    required this.userName
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final WebSocketService _wsService = WebSocketService();
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // Lista local de mensagens

  @override
  void initState() {
    super.initState();
    _wsService.connect();

    // Ouvir novas mensagens chegando do servidor
    _wsService.messages.listen((data) {
      if (data['type'] == 'NEW_CHAT_MESSAGE') {
        // Só mostra a mensagem se for deste Incidente específico
        if (data['incident_id'] == widget.incidentId) {
          setState(() {
            _messages.add(data);
          });
        }
      }
    });
  }

  void _sendMessage() {
    if (_textController.text.isNotEmpty) {
      // Envia JSON para o Python
      _wsService.sendMessage({
        "type": "SEND_CHAT_MESSAGE",
        "incident_id": widget.incidentId,
        "sender_name": widget.userName,
        "content": _textController.text,
      });
      _textController.clear();
    }
  }

  @override
  void dispose() {
    // Não fechamos o WS aqui pois ele é compartilhado, mas em app real gerenciamos melhor
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat Seguro - Ocorrência #${widget.incidentId}"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ÁREA DE MENSAGENS (LISTA)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_name'] == widget.userName;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender_name'], 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 10,
                            color: isMe ? Colors.blue[900] : Colors.black54
                          )
                        ),
                        Text(
                          msg['content'],
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          msg['timestamp'] ?? "",
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ÁREA DE DIGITAÇÃO
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Digite uma mensagem...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}