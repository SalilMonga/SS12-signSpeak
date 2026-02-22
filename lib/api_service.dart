import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({this.baseUrl = 'http://10.0.0.1:8000'});

  void updateIp(String ip) {
    baseUrl = 'http://$ip:8000';
  }

  Future<String> generateSentence(List<String> words) async {
    final uri = Uri.parse('$baseUrl/generate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'aslWords': words}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['sentence'] as String;
    } else {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
  }

  Future<String> summarizeSentences(List<String> sentences) async {
    final uri = Uri.parse('$baseUrl/summarize');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sentences': sentences}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['summary'] as String;
    } else {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
  }
}
