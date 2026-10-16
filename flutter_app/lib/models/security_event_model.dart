class SecurityEventModel {
  final int id;
  final DateTime timestamp;
  final String eventType; // MOTION, ACCESS_GRANTED, INTRUDER_ALERT, MANUAL_UNLOCK, DOOR_LOCKED
  final String title;
  final String? description;
  final String? personName;
  final String? snapshotUrl;
  final bool isCritical;
  final bool isRead;

  SecurityEventModel({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.title,
    this.description,
    this.personName,
    this.snapshotUrl,
    required this.isCritical,
    required this.isRead,
  });

  factory SecurityEventModel.fromJson(Map<String, dynamic> json) {
    return SecurityEventModel(
      id: json['id'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      eventType: json['event_type'] ?? 'UNKNOWN',
      title: json['title'] ?? '',
      description: json['description'],
      personName: json['person_name'],
      snapshotUrl: json['snapshot_url'],
      isCritical: json['is_critical'] ?? false,
      isRead: json['is_read'] ?? false,
    );
  }
}
