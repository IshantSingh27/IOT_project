class ApiConstants {
  // Default host (Use 10.0.2.2 for Android Emulator, localhost for Windows/Web, or your Laptop IP)
  static const String defaultBaseUrl = "http://127.0.0.1:8000";

  // Auth endpoints
  static const String login = "/api/auth/login";
  static const String register = "/api/auth/register";
  static const String me = "/api/auth/me";

  // Door & System endpoints
  static const String status = "/api/door/status";
  static const String unlock = "/api/door/unlock";
  static const String lock = "/api/door/lock";
  static const String simulatePir = "/api/door/simulate-pir";

  // Video feed
  static const String videoStream = "/api/video/feed";
  static const String videoSnapshot = "/api/video/snapshot";

  // Activity Logs
  static const String logs = "/api/logs";
  static const String logStats = "/api/logs/stats";

  // Faces
  static const String faces = "/api/faces";

  // WebSocket
  static const String wsEvents = "/ws/events";
}
