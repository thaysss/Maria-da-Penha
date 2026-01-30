import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; 
import '../../../../core/api/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final int incidentId;
  final String userName; 

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
  final ScrollController _scrollController = ScrollController(); 
  final ImagePicker _picker = ImagePicker(); 
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingHistory = true;

  // Use 127.0.0.1 para Linux/Web ou 10.0.2.2 para Android Emulador
  final String baseUrl = 'http://127.0.0.1:8000'; 

  @override
  void initState() {
    super.initState();
    _loadHistory();     
    _connectRealTime(); 
  }

  // --- 1. BUSCAR HISTÓRICO ---
  Future<void> _loadHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/incidents/${widget.incidentId}/chat')
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _messages = data.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoadingHistory = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print("Erro ao carregar histórico: $e");
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // --- 2. CONEXÃO EM TEMPO REAL ---
  void _connectRealTime() {
    _wsService.connect();
    _wsService.messages.listen((data) {
      if (mounted && 
          data['type'] == 'NEW_CHAT_MESSAGE' && 
          data['incident_id'] == widget.incidentId) {
        
        setState(() {
          _messages.add(data);
        });
        _scrollToBottom();
      }
    });
  }

  // --- 3. ENVIAR IMAGEM (CORRIGIDO PARA LINUX/WEB) ---
  Future<void> _sendImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      
      if (photo != null) {
        setState(() => _isLoadingHistory = true);

        // --- CORREÇÃO AQUI: LER COMO BYTES ---
        // Isso funciona em qualquer plataforma (não depende de dart:io)
        final bytes = await photo.readAsBytes();

        var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
        
        request.files.add(http.MultipartFile.fromBytes(
          'file', 
          bytes,
          filename: photo.name // Mantém o nome original do arquivo
        ));
        
        var response = await request.send();

        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final data = jsonDecode(respStr);
          String imageUrl = data['url'];

          _wsService.sendMessage({
            "type": "SEND_CHAT_MESSAGE",
            "incident_id": widget.incidentId,
            "sender_name": widget.userName,
            "content": "[IMAGEM]:$imageUrl", 
          });
        } else {
          print("Erro no upload: ${response.statusCode}");
        }
        
        if (mounted) setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      print("Erro upload: $e");
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_textController.text.isNotEmpty) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ocorrência #${widget.incidentId}"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory 
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text("Nenhuma mensagem ainda.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_name'] == widget.userName;
                        final content = msg['content'] ?? "";
                        
                        bool isImage = content.startsWith("[IMAGEM]:");
                        String displayContent = isImage ? content.replaceAll("[IMAGEM]:", "") : content;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.indigo.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['sender_name'] ?? "Anônimo", 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 10,
                                    color: isMe ? Colors.indigo : Colors.black54
                                  )
                                ),
                                const SizedBox(height: 4),
                                
                                isImage 
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        displayContent, 
                                        height: 200, 
                                        width: 200,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const SizedBox(
                                            height: 200, width: 200,
                                            child: Center(child: CircularProgressIndicator())
                                          );
                                        },
                                        errorBuilder: (c,e,s) => const Column(
                                          children: [
                                            Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                            Text("Erro ao carregar", style: TextStyle(fontSize: 10))
                                          ],
                                        ),
                                      ),
                                    )
                                  : Text(
                                      displayContent,
                                      style: const TextStyle(fontSize: 16),
                                    ),

                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    msg['timestamp'] ?? "",
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.indigo),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Digite uma mensagem...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.indigo,
                  mini: true,
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}