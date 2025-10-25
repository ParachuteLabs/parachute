import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/recorder/providers/service_providers.dart';

class PlaybackControls extends ConsumerStatefulWidget {
  final String filePath;
  final Duration duration;
  final VoidCallback? onDelete;

  const PlaybackControls({
    super.key,
    required this.filePath,
    required this.duration,
    this.onDelete,
  });

  @override
  ConsumerState<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends ConsumerState<PlaybackControls> {
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _currentPosition = Duration.zero;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    final audioService = ref.read(audioServiceProvider);
    await audioService.initialize();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    if (_isPlaying) {
      final audioService = ref.read(audioServiceProvider);
      audioService.stopPlayback();
    }
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final audioService = ref.read(audioServiceProvider);

    if (_isPlaying && !_isPaused) {
      // Pause playback
      await audioService.pausePlayback();
      setState(() {
        _isPaused = true;
      });
      _progressTimer?.cancel();
    } else if (_isPaused) {
      // Resume playback
      await audioService.resumePlayback();
      setState(() {
        _isPaused = false;
      });
      _startProgressTimer();
    } else {
      // Start playback
      if (widget.filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio file not available for this recording'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final success = await audioService.playRecording(widget.filePath);
      if (success) {
        setState(() {
          _isPlaying = true;
          _isPaused = false;
          _currentPosition = Duration.zero;
        });
        _startProgressTimer();
        // Auto-stop when playback completes
        Future.delayed(widget.duration, () {
          if (_isPlaying && mounted) {
            _stopPlayback();
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to play recording'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying && !_isPaused && mounted) {
        setState(() {
          _currentPosition += const Duration(milliseconds: 100);
          if (_currentPosition >= widget.duration) {
            _currentPosition = widget.duration;
            _stopPlayback();
          }
        });
      }
    });
  }

  Future<void> _stopPlayback() async {
    final audioService = ref.read(audioServiceProvider);

    _progressTimer?.cancel();
    if (_isPlaying) {
      await audioService.stopPlayback();
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _currentPosition = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / widget.duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withAlpha(51),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Time display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(widget.duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop button
              if (_isPlaying)
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopPlayback,
                  tooltip: 'Stop',
                ),
              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isPlaying && !_isPaused
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 48,
                ),
                onPressed: _togglePlayback,
                color: Theme.of(context).colorScheme.primary,
                tooltip: _isPlaying && !_isPaused ? 'Pause' : 'Play',
              ),
              // Delete button
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Recording'),
                        content: const Text(
                            'Are you sure you want to delete this recording?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onDelete!();
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  color: Colors.red,
                  tooltip: 'Delete',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
