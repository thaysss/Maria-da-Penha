import 'package:flutter/material.dart';
import '../../../../core/api/websocket_service.dart';

// Import do Chat (ajuste o caminho se necessário)
import 'package:sos_maria_da_penha_app/features/chat/presentation/chat_screen.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final WebSocketService _wsService = WebSocketService();
  
  Map<String, dynamic>? _currentIncident;
  String _status = "PATRULHAMENTO"; 

  @override
  void initState() {
    super.initState();
    _wsService.connect();
    
    _wsService.messages.listen((data) {
      if (data['type'] == 'NEW_PANIC_ALERT') {
        setState(() {
          _currentIncident = data;
          _status = "ALERTA"; 
        });
      }
    });
  }

  void _acceptIncident() {
    if (_currentIncident != null) {
      _wsService.sendStatusUpdate(_currentIncident!['incident_id'], "DISPATCHED");
      setState(() {
        _status = "EM_DESLOCAMENTO";
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Central notificada: Viatura em deslocamento!")),
      );
    }
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.blue.shade900;
    String statusText = "AGUARDANDO CHAMADOS";
    
    if (_status == "ALERTA") {
      bgColor = Colors.red.shade800;
      statusText = "OCORRÊNCIA RECEBIDA!";
    } else if (_status == "EM_DESLOCAMENTO") {
      bgColor = Colors.green.shade700;
      statusText = "EM DESLOCAMENTO";
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("SOS AGENTE - Viatura 01"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone Principal
              Icon(
                _status == "ALERTA" ? Icons.warning_amber_rounded : Icons.local_police,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              
              Text(
                statusText,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),

              // Card da Ocorrência (GPS)
              if (_currentIncident != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Vítima ID: ${_currentIncident!['victim_id']}",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const Divider(),
                      const Text("Localização recebida via GPS"),
                      Text("Lat: ${_currentIncident!['location']['lat']}"),
                      Text("Lng: ${_currentIncident!['location']['lng']}"),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // Botão de Aceitar
              if (_status == "ALERTA")
                ElevatedButton.icon(
                  onPressed: _acceptIncident,
                  icon: const Icon(Icons.check_circle, size: 30),
                  label: const Text("ACEITAR OCORRÊNCIA", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
                
              // Botão de Chat (Só aparece quando aceita)
              if (_status == "EM_DESLOCAMENTO") ...[
                const Text(
                  "Navegando para o local...",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 20),
                
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("CHAT COM VÍTIMA"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.all(15),
                  ),
                  onPressed: () {
                     // Sem 'const' aqui porque passamos parâmetros
                     Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatScreen(incidentId: 101, userName: "Agente 01")
                     ));
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}