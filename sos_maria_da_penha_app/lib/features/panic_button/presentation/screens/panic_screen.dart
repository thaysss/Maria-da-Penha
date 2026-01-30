import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; 
import '../../data/panic_repository.dart';
import 'package:sos_maria_da_penha_app/features/chat/presentation/chat_screen.dart';
import '../../../../core/api/websocket_service.dart';
// Import da nova tela de histórico
import 'package:sos_maria_da_penha_app/features/history/presentation/screens/history_screen.dart';

class PanicScreen extends StatefulWidget {
  const PanicScreen({super.key});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  final PanicRepository _repository = PanicRepository();
  final _storage = const FlutterSecureStorage();
  final WebSocketService _wsService = WebSocketService();
  Timer? _gpsTimer; 
  
  bool _isLoading = false;
  String _statusMessage = "Toque para pedir ajuda";
  Color _buttonColor = Colors.red;
  int? _currentIncidentId;
  String _userName = "Vítima"; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupWebSocketListener();
    _startGpsTracking(); 
  }

  void _startGpsTracking() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
       try {
         LocationPermission permission = await Geolocator.checkPermission();
         if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
             Position pos = await Geolocator.getCurrentPosition();
             String? idStr = await _storage.read(key: 'user_id');
             
             if (idStr != null) {
               _wsService.sendMessage({
                 "type": "VICTIM_LOCATION_UPDATE", 
                 "user_id": int.parse(idStr),
                 "name": _userName,
                 "lat": pos.latitude,
                 "lng": pos.longitude
               });
             }
         }
       } catch (e) {
         print("Erro GPS Vítima: $e");
       }
    });
  }

  void _setupWebSocketListener() {
    _wsService.connect();
    _wsService.messages.listen((data) {
      if (!mounted) return;

      if (data['type'] == 'CASE_CLOSED' && 
          _currentIncidentId != null && 
          data['incident_id'] == _currentIncidentId) {
            
        setState(() {
          _currentIncidentId = null;
          _isLoading = false;
          _statusMessage = "Atendimento Finalizado.\nVocê está segura.";
          _buttonColor = Colors.red;
        });

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Ocorrência Encerrada"),
            content: Text("Relatório:\n${data['final_report'] ?? 'Sem detalhes.'}"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
            ],
          )
        );
      }
    });
  }

  Future<void> _loadUserData() async {
    String? name = await _storage.read(key: 'name');
    if (name != null) setState(() => _userName = name);
  }

  Future<void> _activatePanic() async {
    setState(() { _isLoading = true; _statusMessage = "Localizando..."; });
    String? userIdStr = await _storage.read(key: 'user_id');
    if (userIdStr == null) return;
    int userId = int.parse(userIdStr);

    if (await Permission.location.request().isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() => _statusMessage = "Enviando Alerta...");
        if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 500);

        int? incidentId = await _repository.sendPanicAlert(
          userId: userId, lat: position.latitude, lng: position.longitude
        );

        if (incidentId != null) {
          setState(() {
            _currentIncidentId = incidentId;
            _isLoading = false;
            _statusMessage = "SOCORRO SOLICITADO! (#$incidentId)";
            _buttonColor = Colors.green;
          });
        } else { _handleResult(false); }
      } catch (e) { _handleResult(false); }
    } else {
      setState(() { _isLoading = false; _statusMessage = "Erro: Precisa de GPS"; });
    }
  }

  void _handleResult(bool success) {
    setState(() {
      _isLoading = false;
      if (!success) _statusMessage = "Falha no envio.";
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Olá, $_userName"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        actions: [
          // --- NOVO BOTÃO DE HISTÓRICO ---
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            onPressed: () async {
              String? uid = await _storage.read(key: 'user_id');
              if (uid != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => HistoryScreen(
                    userId: int.parse(uid), 
                    userRole: "VICTIM",
                    userName: _userName
                  )
                ));
              }
            },
          ),
          // Botão Sair
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.black),
            onPressed: () async {
              await _storage.deleteAll();
              if (context.mounted) Navigator.of(context).pop(); 
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_statusMessage, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 50),
            GestureDetector(
              onTap: _isLoading ? null : _activatePanic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _buttonColor,
                  boxShadow: [BoxShadow(color: _buttonColor.withOpacity(0.4), blurRadius: 30, spreadRadius: 10)],
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app, size: 80, color: Colors.white),
                            Text("SOS", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
            if (_currentIncidentId != null) ...[
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                icon: const Icon(Icons.chat),
                label: const Text("CHAT COM AGENTE"),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(incidentId: _currentIncidentId!, userName: _userName))),
              )
            ]
          ],
        ),
      ),
    );
  }
}