/// Registry space model - represents a space that can be anywhere on the filesystem
class RegistrySpace {
  final String id;
  final String path;
  final String name;
  final DateTime addedAt;
  final DateTime? lastAccessed;
  final String? config;

  RegistrySpace({
    required this.id,
    required this.path,
    required this.name,
    required this.addedAt,
    this.lastAccessed,
    this.config,
  });

  factory RegistrySpace.fromJson(Map<String, dynamic> json) {
    return RegistrySpace(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      addedAt: DateTime.parse(json['added_at'] as String),
      lastAccessed: json['last_accessed'] != null && json['last_accessed'] != '0001-01-01T00:00:00Z'
          ? DateTime.parse(json['last_accessed'] as String)
          : null,
      config: json['config'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'added_at': addedAt.toIso8601String(),
      if (lastAccessed != null) 'last_accessed': lastAccessed!.toIso8601String(),
      if (config != null) 'config': config,
    };
  }
}

/// Parameters for adding an existing space
class AddSpaceParams {
  final String path;
  final String? name;
  final String? config;

  AddSpaceParams({
    required this.path,
    this.name,
    this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      if (name != null) 'name': name,
      if (config != null) 'config': config,
    };
  }
}

/// Parameters for creating a new space
class CreateSpaceParams {
  final String name;
  final String path;
  final String? config;

  CreateSpaceParams({
    required this.name,
    required this.path,
    this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      if (config != null) 'config': config,
    };
  }
}
