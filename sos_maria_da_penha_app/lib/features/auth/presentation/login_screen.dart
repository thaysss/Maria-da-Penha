import 'package:flutter/material.dart';
import '../../../../core/auth/auth_service.dart';

// --- CORREÇÃO: Imports usando o caminho completo (pacote) ---
import 'package:sos_maria_da_penha_app/features/panic_button/presentation/screens/panic_screen.dart';
import 'package:sos_maria_da_penha_app/features/agent_patrol/presentation/screens/agent_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false; 
  String _selectedRole = "VICTIM"; 

  void _submit() async {
    setState(() => _isLoading = true);
    final user = _userController.text;
    final pass = _passController.text;

    if (_isRegistering) {
      // MODO CADASTRO
      bool success = await _auth.register(user, user, pass, _selectedRole);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cadastrado! Faça login.")));
        setState(() => _isRegistering = false);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao cadastrar.")));
      }
    } else {
      // MODO LOGIN
      final data = await _auth.login(user, pass);
      if (data != null) {
        if (!mounted) return;
        
        // --- CORREÇÃO: Removemos o 'const' daqui para evitar erros ---
        if (data['role'] == 'VICTIM') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PanicScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AgentScreen()));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login falhou.")));
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isRegistering ? "Criar Conta" : "SOS Login",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: "Usuário / CPF", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Senha", border: OutlineInputBorder()),
                ),
                if (_isRegistering) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: "VICTIM", child: Text("Sou Vítima")),
                      DropdownMenuItem(value: "AGENT", child: Text("Sou Agente")),
                    ],
                    onChanged: (v) => setState(() => _selectedRole = v!),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Perfil"),
                  )
                ],
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isRegistering ? "CADASTRAR" : "ENTRAR"),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isRegistering = !_isRegistering),
                  child: Text(_isRegistering ? "Já tenho conta" : "Criar nova conta"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}