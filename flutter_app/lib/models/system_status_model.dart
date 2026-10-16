class SystemStatusModel {
  final bool doorLocked;
  final bool pirActive;
  final bool faceRecognitionActive;
  final bool cameraOnline;
  final bool serialConnected;
  final bool simulationMode;
  final DateTime timestamp;

  SystemStatusModel({
    required this.doorLocked,
    required this.pirActive,
    required this.faceRecognitionActive,
    required this.cameraOnline,
    required this.serialConnected,
    required this.simulationMode,
    required this.timestamp,
  });

  factory SystemStatusModel.initial() {
    return SystemStatusModel(
      doorLocked: true,
      pirActive: false,
      faceRecognitionActive: false,
      cameraOnline: false,
      serialConnected: false,
      simulationMode: true,
      timestamp: DateTime.now(),
    );
  }

  factory SystemStatusModel.fromJson(Map<String, dynamic> json) {
    return SystemStatusModel(
      doorLocked: json['door_locked'] ?? true,
      pirActive: json['pir_active'] ?? false,
      faceRecognitionActive: json['face_recognition_active'] ?? false,
      cameraOnline: json['camera_online'] ?? false,
      serialConnected: json['serial_connected'] ?? false,
      simulationMode: json['simulation_mode'] ?? true,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  SystemStatusModel copyWith({
    bool? doorLocked,
    bool? pirActive,
    bool? faceRecognitionActive,
    bool? cameraOnline,
    bool? serialConnected,
    bool? simulationMode,
    DateTime? timestamp,
  }) {
    return SystemStatusModel(
      doorLocked: doorLocked ?? this.doorLocked,
      pirActive: pirActive ?? this.pirActive,
      faceRecognitionActive: faceRecognitionActive ?? this.faceRecognitionActive,
      cameraOnline: cameraOnline ?? this.cameraOnline,
      serialConnected: serialConnected ?? this.serialConnected,
      simulationMode: simulationMode ?? this.simulationMode,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
