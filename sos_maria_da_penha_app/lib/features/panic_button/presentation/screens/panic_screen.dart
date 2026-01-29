import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import '../../data/panic_repository.dart';

// IMPORT CORRIGIDO (Caminho absoluto)
import 'package:sos_maria_da_penha_app/features/chat/presentation/chat_screen.dart';

class PanicScreen extends StatefulWidget {
  const PanicScreen({super.key});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  final PanicRepository _repository = PanicRepository();
  bool _isLoading = false;
  String _statusMessage = "Toque para pedir ajuda";
  Color _buttonColor = Colors.red;

  Future<void> _activatePanic() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Localizando...";
    });

    if (await Permission.location.request().isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        setState(() {
          _statusMessage = "Enviando Alerta...";
        });

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 500);
        }

        bool success = await _repository.sendPanicAlert(
          userId: 1, 
          lat: position.latitude, 
          lng: position.longitude
        );

        _handleResult(success);

      } catch (e) {
        _handleResult(false);
      }
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = "Erro: Precisa de GPS";
      });
    }
  }

  void _handleResult(bool success) {
    setState(() {
      _isLoading = false;
      if (success) {
        _statusMessage = "SOCORRO SOLICITADO!";
        _buttonColor = Colors.green;
      } else {
        _statusMessage = "Falha no envio. Tente novamente!";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("SOS Maria da Penha"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            
            GestureDetector(
              onTap: _isLoading ? null : _activatePanic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _buttonColor,
                  boxShadow: [
                    BoxShadow(
                      color: _buttonColor.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 8)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app, size: 80, color: Colors.white),
                            Text(
                              "SOS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Em caso de perigo iminente, pressione o botão. Sua localização será enviada para a Guarda Municipal.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),

            // BOTÃO DE CHAT CORRIGIDO (Sem 'const')
            if (_statusMessage.contains("SOCORRO")) ...[
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                icon: const Icon(Icons.chat),
                label: const Text("FALAR COM AGENTE AGORA"),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatScreen(incidentId: 101, userName: "Vítima Maria")
                  ));
                },
              )
            ]
          ],
        ),
      ),
    );
  }
}