import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/system_status_model.dart';
import '../models/security_event_model.dart';
import '../models/authorized_person_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../constants/api_constants.dart';

class SecurityProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  SystemStatusModel _status = SystemStatusModel.initial();
  List<SecurityEventModel> _logs = [];
  Map<String, dynamic> _stats = {
    "total_events": 0,
    "events_today": 0,
    "intruders_detected": 0,
    "authorized_unlocks": 0
  };
  List<AuthorizedPersonModel> _faces = [];
  String _baseUrl = ApiConstants.defaultBaseUrl;
  
  bool _isDoorBusy = false;
  Map<String, dynamic>? _latestAlert;

  SystemStatusModel get status => _status;
  List<SecurityEventModel> get logs => _logs;
  Map<String, dynamic> get stats => _stats;
  List<AuthorizedPersonModel> get faces => _faces;
  String get baseUrl => _baseUrl;
  bool get isDoorBusy => _isDoorBusy;
  Map<String, dynamic>? get latestAlert => _latestAlert;

  SecurityProvider() {
    _init();
  }

  Future<void> _init() async {
    _baseUrl = await StorageService.getBaseUrl();
    notifyListeners();
    await fetchInitialData();
    _startWebSocket();
  }

  Future<void> fetchInitialData() async {
    await Future.wait([
      refreshStatus(),
      refreshLogs(),
      refreshStats(),
      refreshFaces(),
    ]);
  }

  void _startWebSocket() {
    _wsSubscription?.cancel();
    _wsService.connect();
    _wsSubscription = _wsService.eventStream.listen((event) {
      _handleWebSocketEvent(event);
    });
  }

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    _latestAlert = event;

    if (type == 'PIR_MOTION') {
      _status = _status.copyWith(
        pirActive: true,
        faceRecognitionActive: true,
      );
    } else if (type == 'PIR_IDLE') {
      _status = _status.copyWith(
        pirActive: false,
        faceRecognitionActive: false,
      );
    } else if (type == 'DOOR_STATE_CHANGED') {
      if (event['door_locked'] != null) {
        _status = _status.copyWith(doorLocked: event['door_locked']);
      }
    } else if (type == 'ACCESS_GRANTED') {
      _status = _status.copyWith(doorLocked: false);
      refreshLogs();
      refreshStats();
    } else if (type == 'INTRUDER_ALERT') {
      refreshLogs();
      refreshStats();
    }

    notifyListeners();
  }

  Future<void> refreshStatus() async {
    try {
      _status = await _apiService.getSystemStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshLogs() async {
    try {
      _logs = await _apiService.getLogs(limit: 40);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshStats() async {
    try {
      _stats = await _apiService.getLogStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshFaces() async {
    try {
      _faces = await _apiService.getFaces();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> toggleDoor() async {
    if (_isDoorBusy) return false;
    _isDoorBusy = true;
    notifyListeners();

    try {
      if (_status.doorLocked) {
        final unlocked = await _apiService.unlockDoor();
        _status = _status.copyWith(doorLocked: !unlocked);
      } else {
        final locked = await _apiService.lockDoor();
        _status = _status.copyWith(doorLocked: locked);
      }
      _isDoorBusy = false;
      notifyListeners();
      refreshLogs();
      return true;
    } catch (e) {
      _isDoorBusy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> simulatePirMotion(bool active) async {
    try {
      await _apiService.simulatePir(active);
    } catch (_) {}
  }

  Future<bool> registerNewFace(String name, String relationship, String imagePath) async {
    try {
      await _apiService.registerFace(name, relationship, imagePath);
      await refreshFaces();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFace(int personId) async {
    try {
      await _apiService.deleteFace(personId);
      await refreshFaces();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    await StorageService.saveBaseUrl(newUrl);
    _baseUrl = await StorageService.getBaseUrl();
    _startWebSocket();
    await fetchInitialData();
    notifyListeners();
  }

  void clearLatestAlert() {
    _latestAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}
