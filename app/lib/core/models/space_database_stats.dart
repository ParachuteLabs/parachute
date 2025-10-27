import 'package:app/core/models/relevant_note.dart';

class SpaceDatabaseStats {
  final String schemaVersion;
  final String spaceId;
  final int createdAt;
  final int totalNotes;
  final List<String> allTags;
  final List<RelevantNote> recentNotes;
  final Map<String, String> metadata;
  final List<String> tables;

  SpaceDatabaseStats({
    required this.schemaVersion,
    required this.spaceId,
    required this.createdAt,
    required this.totalNotes,
    required this.allTags,
    required this.recentNotes,
    required this.metadata,
    required this.tables,
  });

  factory SpaceDatabaseStats.fromJson(Map<String, dynamic> json) {
    return SpaceDatabaseStats(
      schemaVersion: json['schema_version'] as String? ?? '1',
      spaceId: json['space_id'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      totalNotes: json['total_notes'] as int? ?? 0,
      allTags:
          (json['all_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      recentNotes:
          (json['recent_notes'] as List<dynamic>?)
              ?.map((e) => RelevantNote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata:
          (json['metadata'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
      tables:
          (json['tables'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  DateTime get createdAtDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  String get createdAtFormatted {
    final date = createdAtDate;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
