import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/recorder/providers/service_providers.dart';
import 'package:app/features/recorder/screens/post_recording_screen.dart';
import 'package:app/features/recorder/services/audio_service.dart';
import 'package:app/features/recorder/widgets/recording_visualizer.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  RecordingState _recordingState = RecordingState.stopped;
  Duration _recordingDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _startTime;
  DateTime? _pauseStartTime;
  Timer? _timer;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _initializeAndStartRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndStartRecording() async {
    final audioService = ref.read(audioServiceProvider);

    try {
      // Initialize audio service (required)
      await audioService.initialize();

      // Start audio recording
      final success = await audioService.startRecording();
      if (success) {
        _startTime = DateTime.now();
        _startTimer();
        if (mounted) {
          setState(() {
            _recordingState = RecordingState.recording;
          });
        }
        // Try to initialize transcription (optional, non-blocking)
        _initializeTranscription();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to start recording. Please check permissions.'),
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _initializeTranscription() async {
    // NOTE: Real-time transcription is disabled due to microphone conflict.
    // On Android, speech_to_text and flutter_sound cannot access the microphone
    // simultaneously. iOS supports concurrent access but Android does not.
    //
    // Alternative solutions:
    // 1. Use post-recording transcription with cloud APIs (Whisper, Google STT)
    // 2. Use vosk_flutter for offline transcription with audio stream
    // 3. Implement transcription after recording completes
    //
    // For now, transcription is left as a placeholder for future implementation.
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_recordingState == RecordingState.recording && _startTime != null) {
        setState(() {
          // Calculate total duration minus paused time
          final totalElapsed = DateTime.now().difference(_startTime!);
          _recordingDuration = totalElapsed - _pausedDuration;
        });
      } else if (_recordingState == RecordingState.stopped) {
        timer.cancel();
      }
    });
  }

  Future<void> _pauseRecording() async {
    final audioService = ref.read(audioServiceProvider);

    if (_recordingState == RecordingState.recording) {
      final success = await audioService.pauseRecording();
      if (success) {
        _pauseStartTime = DateTime.now();
        _timer?.cancel();
        setState(() {
          _recordingState = RecordingState.paused;
        });
      }
    } else if (_recordingState == RecordingState.paused) {
      final success = await audioService.resumeRecording();
      if (success) {
        // Add the paused duration to total paused time
        if (_pauseStartTime != null) {
          _pausedDuration += DateTime.now().difference(_pauseStartTime!);
          _pauseStartTime = null;
        }
        setState(() {
          _recordingState = RecordingState.recording;
        });
        _startTimer();
      }
    }
  }

  Future<void> _stopRecording() async {
    final audioService = ref.read(audioServiceProvider);

    _timer?.cancel();
    setState(() {
      _recordingState = RecordingState.stopped;
    });

    // Transcription is currently disabled due to microphone conflicts
    String transcription = '';

    final path = await audioService.stopRecording();

    if (path != null && mounted) {
      _recordingPath = path;
      // Calculate final duration
      if (_startTime != null) {
        final totalElapsed = DateTime.now().difference(_startTime!);
        _recordingDuration = totalElapsed - _pausedDuration;
      }
      _navigateToPostRecording(transcription);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save recording'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _navigateToPostRecording(String transcription) {
    if (_recordingPath != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PostRecordingScreen(
            recordingPath: _recordingPath!,
            duration: _recordingDuration,
            initialTranscript: transcription.isNotEmpty ? transcription : null,
          ),
        ),
      );
    }
  }

  String get _formattedDuration {
    final minutes = _recordingDuration.inMinutes;
    final seconds = _recordingDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Recording'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Recording status
            Text(
              _recordingState == RecordingState.recording
                  ? 'Recording...'
                  : _recordingState == RecordingState.paused
                      ? 'Paused'
                      : 'Initializing...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _recordingState == RecordingState.recording
                        ? Theme.of(context).colorScheme.primary
                        : _recordingState == RecordingState.paused
                            ? Colors.orange
                            : Colors.grey,
                  ),
            ),
            const SizedBox(height: 20),
            // Recording visualizer
            RecordingVisualizer(
              isRecording: _recordingState == RecordingState.recording,
            ),
            const SizedBox(height: 30),
            // Duration display
            Text(
              _formattedDuration,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 20),
            // Recording indicator
            if (_recordingState == RecordingState.recording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('recording...'),
                ],
              ),
            const SizedBox(height: 20),
            const Spacer(),
            // Control buttons
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pause/Resume button
                  FloatingActionButton(
                    heroTag: 'pauseButton',
                    onPressed: _recordingState != RecordingState.stopped
                        ? _pauseRecording
                        : null,
                    backgroundColor: _recordingState != RecordingState.stopped
                        ? Colors.orange
                        : Colors.grey,
                    child: Icon(
                      _recordingState == RecordingState.recording
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  // Stop button
                  FloatingActionButton(
                    heroTag: 'stopButton',
                    onPressed: _recordingState != RecordingState.stopped
                        ? _stopRecording
                        : null,
                    backgroundColor: _recordingState != RecordingState.stopped
                        ? Colors.red
                        : Colors.grey,
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Text('Tap stop to finish recording'),
          ],
        ),
      ),
    );
  }
}
