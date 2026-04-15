import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Android emulator → 10.0.2.2 maps to host machine localhost
const String _apiBase = 'http://192.168.0.187/lookmax_backend';
// Real device on same WiFi → use your PC's local IP:
// const String _apiBase = 'http://192.168.x.x/lookmax_backend';

class ApiService {
  static Future<String?> _token() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return u.getIdToken();
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_apiBase$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Request failed');
    }
    return body;
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_apiBase$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Request failed');
    }
    return body;
  }
}
