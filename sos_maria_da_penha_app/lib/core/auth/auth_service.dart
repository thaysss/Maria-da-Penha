import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String baseUrl = 'http://127.0.0.1:8000'; // Ajuste o IP
  final _storage = const FlutterSecureStorage();

  // Tenta fazer login
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token'),
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Salva tudo no cofre seguro
        await _storage.write(key: 'token', value: data['access_token']);
        await _storage.write(key: 'role', value: data['role']);
        await _storage.write(key: 'user_id', value: data['user_id'].toString());
        await _storage.write(key: 'name', value: data['name']);
        return data;
      }
      return null;
    } catch (e) {
      print("Erro login: $e");
      return null;
    }
  }

  // Registra novo usuário (Para teste)
  Future<bool> register(String name, String username, String password, String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "username": username,
        "password": password,
        "role": role,
        "full_name": name
      }),
    );
    return response.statusCode == 201;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // Verifica se já está logado
  Future<String?> getToken() async => await _storage.read(key: 'token');
}