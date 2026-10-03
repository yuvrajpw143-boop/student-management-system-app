import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Set at build time: --dart-define=API_URL=https://your-api.example.com
const apiBase = String.fromEnvironment('API_URL', defaultValue: 'https://student-management-system-app-production-aeca.up.railway.app');

class Api {
  static String? token;
  static Future<void> load() async => token = (await SharedPreferences.getInstance()).getString('t');
  static Future<void> save(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t == null ? await p.remove('t') : await p.setString('t', t);
  }

  static Future call(String m, String path, [Map? body]) async {
    final req = http.Request(m, Uri.parse('$apiBase/api$path'))
      ..headers.addAll({'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'});
    if (body != null) req.body = jsonEncode(body);
    final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
    final d = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode == 401 && token != null) await save(null);
    if (r.statusCode >= 400) throw (d is Map ? d['error'] : null) ?? 'Request failed (${r.statusCode})';
    return d;
  }
}
