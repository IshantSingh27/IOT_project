class AuthorizedPersonModel {
  final int id;
  final String name;
  final String relationship;
  final String? photoFilename;
  final bool isActive;
  final DateTime createdAt;

  AuthorizedPersonModel({
    required this.id,
    required this.name,
    required this.relationship,
    this.photoFilename,
    required this.isActive,
    required this.createdAt,
  });

  factory AuthorizedPersonModel.fromJson(Map<String, dynamic> json) {
    return AuthorizedPersonModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? 'Family',
      photoFilename: json['photo_filename'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
