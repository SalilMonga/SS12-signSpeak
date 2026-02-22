import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> ollamaChatFromAslWords(List<String> aslWords) async {
  final uri = Uri.parse('http://127.0.0.1:8000/generate');

  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'aslWords': aslWords}),
  );

  if (resp.statusCode != 200) {
    throw Exception('Backend error ${resp.statusCode}: ${resp.body}');
  }

  final data = jsonDecode(resp.body) as Map<String, dynamic>;
  return (data['sentence'] as String).trim();
}