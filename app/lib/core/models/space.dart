class Space {
  final String id;
  final String userId;
  final String name;
  final String path;
  final DateTime createdAt;
  final DateTime updatedAt;

  Space({
    required this.id,
    required this.userId,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'path': path,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Space copyWith({
    String? id,
    String? userId,
    String? name,
    String? path,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Space(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
