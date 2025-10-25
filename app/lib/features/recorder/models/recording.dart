/// Source of a recording (phone microphone or Omi device)
enum RecordingSource {
  phone,
  omiDevice;

  @override
  String toString() {
    switch (this) {
      case RecordingSource.phone:
        return 'phone';
      case RecordingSource.omiDevice:
        return 'omiDevice';
    }
  }

  static RecordingSource fromString(String value) {
    switch (value.toLowerCase()) {
      case 'omidevice':
        return RecordingSource.omiDevice;
      case 'phone':
      default:
        return RecordingSource.phone;
    }
  }
}

class Recording {
  final String id;
  final String title;
  final String filePath;
  final DateTime timestamp;
  final Duration duration;
  final List<String> tags;
  final String transcript;
  final double fileSizeKB;
  final RecordingSource source;
  final String? deviceId; // Omi device ID if from device
  final int? buttonTapCount; // 1, 2, or 3 for device button taps

  Recording({
    required this.id,
    required this.title,
    required this.filePath,
    required this.timestamp,
    required this.duration,
    required this.tags,
    required this.transcript,
    required this.fileSizeKB,
    this.source = RecordingSource.phone,
    this.deviceId,
    this.buttonTapCount,
  })  : assert(id.isNotEmpty, 'Recording ID cannot be empty'),
        assert(title.isNotEmpty, 'Recording title cannot be empty'),
        assert(filePath.isNotEmpty, 'Recording file path cannot be empty'),
        assert(duration >= Duration.zero, 'Duration must be non-negative'),
        assert(fileSizeKB >= 0, 'File size must be non-negative'),
        assert(
            source == RecordingSource.phone ||
                (source == RecordingSource.omiDevice && deviceId != null),
            'Device ID required for omiDevice source'),
        assert(
            buttonTapCount == null ||
                (buttonTapCount >= 1 && buttonTapCount <= 3),
            'Button tap count must be 1, 2, or 3 if provided');

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'duration': duration.inMilliseconds,
        'tags': tags,
        'transcript': transcript,
        'fileSizeKB': fileSizeKB,
        'source': source.toString(),
        'deviceId': deviceId,
        'buttonTapCount': buttonTapCount,
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        filePath: json['filePath'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        duration: Duration(milliseconds: json['duration'] as int? ?? 0),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        transcript: json['transcript'] as String? ?? '',
        fileSizeKB: (json['fileSizeKB'] as num?)?.toDouble() ?? 0.0,
        source: json['source'] != null
            ? RecordingSource.fromString(json['source'] as String)
            : RecordingSource.phone,
        deviceId: json['deviceId'] as String?,
        buttonTapCount: json['buttonTapCount'] as int?,
      );

  String get durationString {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeKB < 1024) {
      return '${fileSizeKB.toStringAsFixed(1)}KB';
    }
    return '${(fileSizeKB / 1024).toStringAsFixed(1)}MB';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
