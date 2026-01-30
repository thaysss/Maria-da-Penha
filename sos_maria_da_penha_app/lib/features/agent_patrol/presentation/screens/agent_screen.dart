import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; 
import 'dart:async'; 
import 'dart:convert';
import '../../../../core/api/websocket_service.dart';
import 'package:sos_maria_da_penha_app/features/chat/presentation/chat_screen.dart';
// Import da tela de histórico
import 'package:sos_maria_da_penha_app/features/history/presentation/screens/history_screen.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final WebSocketService _wsService = WebSocketService();
  final _storage = const FlutterSecureStorage();
  Timer? _gpsTimer; 
  
  // Use o IP correto (127.0.0.1 ou 10.0.2.2)
  final String baseUrl = 'http://127.0.0.1:8000'; 

  Map<String, dynamic>? _currentIncident;
  String _status = "PATRULHAMENTO"; 
  String _agentName = "Agente"; 

  @override
  void initState() {
    super.initState();
    _loadAgentData();
    _wsService.connect();
    _startGpsTracking(); 
    
    _wsService.messages.listen((data) {
      if (!mounted) return;

      // 1. RECEBIMENTO DE ALERTAS
      if (data['type'] == 'NEW_PANIC_ALERT' && _status == "PATRULHAMENTO") {
        
        // Verifica se o chamado foi direcionado ESPECIFICAMENTE para este agente
        if (data['target_agent_name'] != null) {
          if (data['target_agent_name'] == _agentName) {
            // É pra mim! Prioridade máxima!
            setState(() {
              _currentIncident = data;
              _status = "ALERTA_PRIORITARIO"; 
            });
            _showPriorityDialog();
          }
        } else {
          // Alerta genérico
          setState(() {
            _currentIncident = data;
            _status = "ALERTA"; 
          });
        }
      }
      
      // 2. FECHAMENTO DE CASO
      if (data['type'] == 'CASE_CLOSED') {
        if (_currentIncident != null && data['incident_id'] == _currentIncident!['incident_id']) {
           _resetPatrol();
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Ocorrência Finalizada!")),
           );
        }
      }
    });
  }

  void _startGpsTracking() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
       try {
         Position pos = await Geolocator.getCurrentPosition();
         String? idStr = await _storage.read(key: 'user_id');
         
         if (idStr != null) {
           _wsService.sendMessage({
             "type": "AGENT_LOCATION_UPDATE",
             "user_id": int.parse(idStr),
             "name": _agentName,
             "lat": pos.latitude,
             "lng": pos.longitude
           });
         }
       } catch (e) {
         print("Erro GPS background: $e");
       }
    });
  }

  Future<void> _loadAgentData() async {
    String? name = await _storage.read(key: 'name');
    if (name != null && mounted) setState(() => _agentName = name);
  }

  void _resetPatrol() {
    if (mounted) {
      setState(() {
        _currentIncident = null;
        _status = "PATRULHAMENTO";
      });
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _showPriorityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🚨 VOCÊ É A VIATURA MAIS PRÓXIMA!"),
        content: const Text("A central designou esta ocorrência para você com prioridade máxima."),
        backgroundColor: Colors.red.shade100,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("ENTENDIDO")
          )
        ],
      )
    );
  }

  Future<void> _openMap() async {
    if (_currentIncident == null) return;
    final lat = _currentIncident!['location']['lat'];
    final lng = _currentIncident!['location']['lng'];
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) { print(e); }
  }

  void _showFinishDialog() {
    final reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finalizar Ocorrência"),
        content: TextField(
          controller: reportController,
          decoration: const InputDecoration(hintText: "Relatório Final"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _finishIncident(reportController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("FINALIZAR"),
          )
        ],
      ),
    );
  }

  Future<void> _finishIncident(String report) async {
    if (_currentIncident == null) return;
    try {
      final id = _currentIncident!['incident_id'];
      await http.put(
        Uri.parse('$baseUrl/api/incidents/$id/close'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"final_report": report})
      );
      _resetPatrol(); 
    } catch (e) { print(e); }
  }

  void _acceptIncident() {
    if (_currentIncident != null) {
      _wsService.sendStatusUpdate(_currentIncident!['incident_id'], "DISPATCHED");
      setState(() => _status = "EM_DESLOCAMENTO");
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.blue.shade900;
    String statusText = "AGUARDANDO CHAMADOS";
    
    if (_status == "ALERTA" || _status == "ALERTA_PRIORITARIO") {
      bgColor = Colors.red.shade800;
      statusText = "OCORRÊNCIA RECEBIDA!";
    } else if (_status == "EM_DESLOCAMENTO") {
      bgColor = Colors.green.shade700;
      statusText = "EM DESLOCAMENTO";
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("$_agentName - Viatura 01"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // --- NOVO BOTÃO DE HISTÓRICO ---
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () async {
              String? uid = await _storage.read(key: 'user_id');
              if (uid != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => HistoryScreen(
                    userId: int.parse(uid), 
                    userRole: "AGENT", // Define que é Agente (vê tudo)
                    userName: _agentName
                  )
                ));
              }
            },
          ),
          // Botão Sair
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _storage.deleteAll();
              if (context.mounted) Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_status == "ALERTA_PRIORITARIO")
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text("⚠️ PRIORIDADE MÁXIMA ⚠️", style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                
              Icon(
                _status.contains("ALERTA") ? Icons.warning_amber_rounded : Icons.local_police,
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

              if (_currentIncident != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text("Vítima: ${_currentIncident!['victim_name']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              if (_status.contains("ALERTA"))
                ElevatedButton.icon(
                  onPressed: _acceptIncident,
                  icon: const Icon(Icons.check_circle, size: 30),
                  label: const Text("ACEITAR", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
                
              if (_status == "EM_DESLOCAMENTO") ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text("GPS"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: _openMap,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text("CHAT"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green),
                  onPressed: () {
                     Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          incidentId: _currentIncident!['incident_id'], 
                          userName: _agentName 
                        )
                     ));
                  },
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text("FINALIZAR"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
                  onPressed: _showFinishDialog,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}