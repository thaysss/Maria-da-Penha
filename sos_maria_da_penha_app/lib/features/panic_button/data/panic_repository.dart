import 'dart:convert';
import 'package:http/http.dart' as http;

// ... imports

class PanicRepository {
  // Ajuste para o seu IP ou localhost
  final String baseUrl = 'http://127.0.0.1:8000'; 

  // Mudamos o retorno de bool para int? (pode ser nulo se falhar)
  Future<int?> sendPanicAlert({
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
        final data = jsonDecode(response.body);
        return data['incident_id']; // Retorna o ID gerado (Ex: 1, 2, 3...)
      } else {
        return null;
      }
    } catch (e) {
      print("Erro: $e");
      return null;
    }
  }
}