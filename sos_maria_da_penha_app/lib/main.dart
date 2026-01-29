import 'package:flutter/material.dart';
// Importando as telas que criamos antes
import 'features/panic_button/presentation/screens/panic_screen.dart';
import 'features/agent_patrol/presentation/screens/agent_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOS Guarda Municipal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MenuScreen(),
    );
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Simulador de Segurança")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Escolha um Perfil para Testar:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // BOTÃO MODO VÍTIMA
            ElevatedButton.icon(
              icon: const Icon(Icons.touch_app, size: 40, color: Colors.red),
              label: const Text("MODO VÍTIMA\n(Botão de Pânico)", textAlign: TextAlign.center),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.red.shade50,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PanicScreen()),
                );
              },
            ),
            
            const SizedBox(height: 20),

            // BOTÃO MODO AGENTE
            ElevatedButton.icon(
              icon: const Icon(Icons.local_police, size: 40, color: Colors.blue),
              label: const Text("MODO AGENTE\n(Viatura Policial)", textAlign: TextAlign.center),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.blue.shade50,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AgentScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}