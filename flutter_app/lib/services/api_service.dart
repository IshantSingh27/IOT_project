import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import '../models/user_model.dart';
import '../models/system_status_model.dart';
import '../models/security_event_model.dart';
import '../models/authorized_person_model.dart';
import 'storage_service.dart';

class ApiService {
  Future<String> _getUrl(String endpoint) async {
    final base = await StorageService.getBaseUrl();
    return "$base$endpoint";
  }

  Future<Map<String, String>> _headers() async {
    final token = await StorageService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Auth API ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = await _getUrl(ApiConstants.login);
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Login failed. Please check credentials.');
    }
  }

  Future<UserModel> register(String email, String password, String? fullName) async {
    final url = await _getUrl(ApiConstants.register);
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'full_name': fullName}),
    );

    if (response.statusCode == 201) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Registration failed.');
    }
  }

  Future<UserModel> getMe() async {
    final url = await _getUrl(ApiConstants.me);
    final headers = await _headers();
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Session expired. Please log in again.');
    }
  }

  // --- Door & System API ---
  Future<SystemStatusModel> getSystemStatus() async {
    final url = await _getUrl(ApiConstants.status);
    final headers = await _headers();
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return SystemStatusModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch system status');
    }
  }

  Future<bool> unlockDoor() async {
    final url = await _getUrl(ApiConstants.unlock);
    final headers = await _headers();
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'action': 'unlock', 'reason': 'Manual Unlock from Mobile App'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['door_locked'] == false;
    } else {
      throw Exception('Failed to unlock door');
    }
  }

  Future<bool> lockDoor() async {
    final url = await _getUrl(ApiConstants.lock);
    final headers = await _headers();
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'action': 'lock', 'reason': 'Manual Lock from Mobile App'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['door_locked'] == true;
    } else {
      throw Exception('Failed to lock door');
    }
  }

  Future<void> simulatePir(bool active) async {
    final url = await _getUrl("${ApiConstants.simulatePir}?active=$active");
    final headers = await _headers();
    await http.post(Uri.parse(url), headers: headers);
  }

  // --- Activity Logs API ---
  Future<List<SecurityEventModel>> getLogs({int limit = 50, bool criticalOnly = false}) async {
    final url = await _getUrl("${ApiConstants.logs}?limit=$limit&critical_only=$criticalOnly");
    final headers = await _headers();
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((e) => SecurityEventModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load activity logs');
    }
  }

  Future<Map<String, dynamic>> getLogStats() async {
    final url = await _getUrl(ApiConstants.logStats);
    final headers = await _headers();
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        "total_events": 0,
        "events_today": 0,
        "intruders_detected": 0,
        "authorized_unlocks": 0
      };
    }
  }

  // --- Face Management API ---
  Future<List<AuthorizedPersonModel>> getFaces() async {
    final url = await _getUrl(ApiConstants.faces);
    final headers = await _headers();
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((e) => AuthorizedPersonModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load authorized faces');
    }
  }

  Future<AuthorizedPersonModel> registerFace(String name, String relationship, String imagePath) async {
    final url = await _getUrl(ApiConstants.faces);
    final token = await StorageService.getToken();

    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['name'] = name;
    request.fields['relationship'] = relationship;

    final file = File(imagePath);
    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        file.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return AuthorizedPersonModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to register face.');
    }
  }

  Future<void> deleteFace(int personId) async {
    final url = await _getUrl("${ApiConstants.faces}/$personId");
    final headers = await _headers();
    final response = await http.delete(Uri.parse(url), headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete authorized person');
    }
  }
}
