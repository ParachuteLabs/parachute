/// Model for a note linked to a space with space-specific context
class RelevantNote {
  final String id;
  final String captureId;
  final String notePath;
  final DateTime linkedAt;
  final String context;
  final List<String> tags;
  final DateTime? lastReferenced;
  final Map<String, dynamic>? metadata;

  RelevantNote({
    required this.id,
    required this.captureId,
    required this.notePath,
    required this.linkedAt,
    required this.context,
    required this.tags,
    this.lastReferenced,
    this.metadata,
  });

  factory RelevantNote.fromJson(Map<String, dynamic> json) {
    return RelevantNote(
      id: json['id'] as String,
      captureId: json['capture_id'] as String,
      notePath: json['note_path'] as String,
      linkedAt: DateTime.parse(json['linked_at'] as String),
      context: json['context'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      lastReferenced: json['last_referenced'] != null
          ? DateTime.parse(json['last_referenced'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'capture_id': captureId,
      'note_path': notePath,
      'linked_at': linkedAt.toIso8601String(),
      'context': context,
      'tags': tags,
      'last_referenced': lastReferenced?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Get filename from note path
  String get filename {
    return notePath.split('/').last;
  }

  /// Get human-readable time since linked
  String get linkedTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(linkedAt);

    if (difference.inDays > 30) {
      final months = difference.inDays ~/ 30;
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Get human-readable time since last referenced
  String? get lastReferencedTimeAgo {
    if (lastReferenced == null) return null;

    final now = DateTime.now();
    final difference = now.difference(lastReferenced!);

    if (difference.inDays > 30) {
      final months = difference.inDays ~/ 30;
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  RelevantNote copyWith({
    String? id,
    String? captureId,
    String? notePath,
    DateTime? linkedAt,
    String? context,
    List<String>? tags,
    DateTime? lastReferenced,
    Map<String, dynamic>? metadata,
  }) {
    return RelevantNote(
      id: id ?? this.id,
      captureId: captureId ?? this.captureId,
      notePath: notePath ?? this.notePath,
      linkedAt: linkedAt ?? this.linkedAt,
      context: context ?? this.context,
      tags: tags ?? this.tags,
      lastReferenced: lastReferenced ?? this.lastReferenced,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Request to link a note to a space
class LinkNoteRequest {
  final String captureId;
  final String notePath;
  final String context;
  final List<String> tags;

  LinkNoteRequest({
    required this.captureId,
    required this.notePath,
    required this.context,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'capture_id': captureId,
      'note_path': notePath,
      'context': context,
      'tags': tags,
    };
  }
}

/// Request to update note context in a space
class UpdateNoteContextRequest {
  final String? context;
  final List<String>? tags;

  UpdateNoteContextRequest({this.context, this.tags});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (context != null) json['context'] = context;
    if (tags != null) json['tags'] = tags;
    return json;
  }
}

/// Response from getting note content with space context
class NoteWithContext {
  final String captureId;
  final String notePath;
  final String content;
  final String spaceContext;
  final List<String> tags;
  final DateTime linkedAt;
  final DateTime? lastReferenced;

  NoteWithContext({
    required this.captureId,
    required this.notePath,
    required this.content,
    required this.spaceContext,
    required this.tags,
    required this.linkedAt,
    this.lastReferenced,
  });

  factory NoteWithContext.fromJson(Map<String, dynamic> json) {
    return NoteWithContext(
      captureId: json['capture_id'] as String,
      notePath: json['note_path'] as String,
      content: json['content'] as String,
      spaceContext: json['space_context'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      linkedAt: DateTime.parse(json['linked_at'] as String),
      lastReferenced: json['last_referenced'] != null
          ? DateTime.parse(json['last_referenced'] as String)
          : null,
    );
  }
}
