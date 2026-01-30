import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sos_maria_da_penha_app/features/chat/presentation/chat_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int userId;
  final String userRole; // "VICTIM" ou "AGENT"
  final String userName;

  const HistoryScreen({
    super.key, 
    required this.userId, 
    required this.userRole,
    required this.userName
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _incidents = [];
  bool _isLoading = true;
  final String baseUrl = 'http://127.0.0.1:8000'; 

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    String url;
    if (widget.userRole == 'AGENT') {
      // Agente vê tudo
      url = '$baseUrl/api/incidents';
    } else {
      // Vítima vê só os dela
      url = '$baseUrl/api/users/${widget.userId}/incidents';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _incidents = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro histórico: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Histórico de Ocorrências"),
        backgroundColor: widget.userRole == 'AGENT' ? Colors.blue.shade900 : Colors.white,
        foregroundColor: widget.userRole == 'AGENT' ? Colors.white : Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _incidents.isEmpty 
            ? const Center(child: Text("Nenhum registro encontrado."))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _incidents.length,
                itemBuilder: (context, index) {
                  final item = _incidents[index];
                  final bool isOpen = item['status'] == 'OPEN';
                  
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOpen ? Colors.red : Colors.grey,
                        child: Icon(
                          isOpen ? Icons.warning : Icons.check, 
                          color: Colors.white
                        ),
                      ),
                      title: Text(
                        widget.userRole == 'AGENT' 
                          ? "Vítima: ${item['victim_name'] ?? 'Desconhecido'}" 
                          : "Chamado #${item['id']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Data: ${item['date']}"),
                          Text("Status: ${item['status'] == 'OPEN' ? 'EM ANDAMENTO' : 'FINALIZADO'}"),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Ao clicar, abre o chat daquele incidente para ver o que aconteceu
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            incidentId: item['id'], 
                            userName: widget.userName
                          )
                        ));
                      },
                    ),
                  );
                },
              ),
    );
  }
}