import 'dart:convert';
import 'package:http/http.dart' as http;

class PanicRepository {
  // Use o IP da sua máquina se estiver rodando local (ex: 192.168.x.x)
  // Emulador Android usa 10.0.2.2 para acessar o localhost do PC
  final String baseUrl = 'http://127.0.0.1:8000'; 

  Future<bool> sendPanicAlert({
    required int userId,
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse('$baseUrl/api/panic');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode == 201) {
        print("Pânico enviado com sucesso: ${response.body}");
        return true;
      } else {
        print("Erro na API: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Erro de conexão: $e");
      return false;
    }
  }
}