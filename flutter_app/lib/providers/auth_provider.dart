import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> tryAutoLogin() async {
    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      _currentUser = await _apiService.getMe();
      notifyListeners();
      return true;
    } catch (e) {
      await StorageService.clearAuth();
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.login(email, password);
      final token = res['access_token'];
      await StorageService.saveToken(token);
      _currentUser = UserModel.fromJson(res['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String? fullName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.register(email, password, fullName);
      // Auto-login after registration
      return await login(email, password);
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.clearAuth();
    _currentUser = null;
    notifyListeners();
  }
}
