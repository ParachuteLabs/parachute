import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/recorder/models/recording.dart';
import 'package:app/features/recorder/providers/service_providers.dart';
import 'package:app/features/settings/screens/settings_screen.dart';
import 'package:app/features/recorder/services/whisper_service.dart';
import 'package:app/features/recorder/services/whisper_local_service.dart';
import 'package:app/features/recorder/models/whisper_models.dart';
import 'package:app/core/providers/title_generation_provider.dart';

class PostRecordingScreen extends ConsumerStatefulWidget {
  final String recordingPath;
  final Duration duration;
  final String? initialTranscript;

  const PostRecordingScreen({
    super.key,
    required this.recordingPath,
    required this.duration,
    this.initialTranscript,
  });

  @override
  ConsumerState<PostRecordingScreen> createState() =>
      _PostRecordingScreenState();
}

class _PostRecordingScreenState extends ConsumerState<PostRecordingScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _transcriptController = TextEditingController();

  bool _isPlaying = false;
  bool _isSaving = false;
  bool _isTranscribing = false;
  double _transcriptionProgress = 0.0;
  String _transcriptionStatus = '';

  @override
  void initState() {
    super.initState();
    // Generate a default title with date and time
    final now = DateTime.now();
    final dateStr =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _titleController.text = 'Recording $dateStr';

    // Use the transcription from the recording if available
    _transcriptController.text = widget.initialTranscript ?? '';

    // Check if auto-transcribe is enabled
    _checkAutoTranscribe();
  }

  Future<void> _checkAutoTranscribe() async {
    final storageService = ref.read(storageServiceProvider);
    final autoTranscribe = await storageService.getAutoTranscribe();

    // If auto-transcribe is enabled and no transcript exists, start transcription
    if (autoTranscribe &&
        (widget.initialTranscript == null ||
            widget.initialTranscript!.isEmpty)) {
      // Delay slightly to let the UI render first
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _transcribeRecording();
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await ref.read(audioServiceProvider).stopPlayback();
      setState(() => _isPlaying = false);
    } else {
      final success = await ref
          .read(audioServiceProvider)
          .playRecording(widget.recordingPath);
      if (success) {
        setState(() => _isPlaying = true);
        // Auto-stop after duration (simplified)
        Future.delayed(widget.duration, () {
          if (mounted && _isPlaying) {
            setState(() => _isPlaying = false);
          }
        });
      }
    }
  }

  Future<void> _transcribeRecording() async {
    if (_isTranscribing) return;

    // Get transcription mode
    final storageService = ref.read(storageServiceProvider);
    final modeString = await storageService.getTranscriptionMode();
    final mode =
        TranscriptionMode.fromString(modeString) ?? TranscriptionMode.api;

    setState(() {
      _isTranscribing = true;
      _transcriptionProgress = 0.0;
      _transcriptionStatus = 'Starting...';
    });

    try {
      String transcript;

      if (mode == TranscriptionMode.local) {
        // Use local Whisper
        transcript = await _transcribeWithLocal();
      } else {
        // Use OpenAI API
        transcript = await _transcribeWithAPI();
      }

      if (mounted) {
        _transcriptController.text = transcript;
        setState(() {
          _transcriptionProgress = 1.0;
          _transcriptionStatus = 'Complete!';
        });

        // Auto-generate title from transcript
        _generateTitleFromTranscript(transcript);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcription completed!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription failed: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _transcriptionProgress = 0.0;
          _transcriptionStatus = '';
        });
      }
    }
  }

  Future<void> _generateTitleFromTranscript(String transcript) async {
    debugPrint(
      '[PostRecording] _generateTitleFromTranscript called with ${transcript.length} chars',
    );

    if (transcript.isEmpty) {
      debugPrint(
        '[PostRecording] Transcript is empty, skipping title generation',
      );
      return;
    }

    try {
      debugPrint('[PostRecording] Getting title service...');
      final titleService = ref.read(titleGenerationServiceProvider);

      debugPrint('[PostRecording] Calling generateTitle...');
      final generatedTitle = await titleService.generateTitle(transcript);

      debugPrint('[PostRecording] Generated title: "$generatedTitle"');

      if (generatedTitle != null && generatedTitle.isNotEmpty && mounted) {
        debugPrint('[PostRecording] Setting title to: "$generatedTitle"');
        setState(() {
          _titleController.text = generatedTitle;
        });
      } else {
        debugPrint('[PostRecording] Generated title was null or empty');
      }
    } catch (e) {
      // Silent fail - keep the default title if generation fails
      debugPrint('[PostRecording] ❌ Title generation failed: $e');
    }
  }

  Future<String> _transcribeWithLocal() async {
    final localService = ref.read(whisperLocalServiceProvider);

    // Check if ready
    final isReady = await localService.isReady();
    if (!isReady) {
      if (!mounted) throw WhisperLocalException('Not mounted');

      // Show dialog to navigate to settings
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Model Required'),
          content: const Text(
            'To use local transcription, you need to download a Whisper model in Settings.\n\n'
            'Would you like to go to Settings now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );

      if (goToSettings == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      }
      throw WhisperLocalException('Model not downloaded');
    }

    // Transcribe with progress updates
    return await localService.transcribeAudio(
      widget.recordingPath,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _transcriptionProgress = progress.progress;
            _transcriptionStatus = progress.status;
          });
        }
      },
    );
  }

  Future<String> _transcribeWithAPI() async {
    // Check if API key is configured
    final isConfigured = await ref.read(whisperServiceProvider).isConfigured();
    if (!isConfigured) {
      if (!mounted) throw WhisperException('Not mounted');

      // Show dialog to navigate to settings
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Key Required'),
          content: const Text(
            'To use transcription, you need to configure your OpenAI API key in Settings.\n\n'
            'Would you like to go to Settings now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );

      if (goToSettings == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      }
      throw WhisperException('API key not configured');
    }

    setState(() => _transcriptionStatus = 'Uploading to OpenAI...');

    return await ref
        .read(whisperServiceProvider)
        .transcribeAudio(widget.recordingPath);
  }

  Future<void> _saveRecording() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final fileSizeKB = await ref
          .read(audioServiceProvider)
          .getFileSizeKB(widget.recordingPath);

      // Extract recording ID from the file path
      // Path format: /path/to/2025-10-06-1759784172526.m4a
      final fileName = widget.recordingPath.split('/').last;
      final recordingId = fileName.replaceAll('.m4a', '').split('-').last;

      final recording = Recording(
        id: recordingId,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Untitled Recording',
        filePath: widget.recordingPath,
        timestamp: DateTime.now(),
        duration: widget.duration,
        tags: [], // Tags removed - keeping field for backwards compatibility
        transcript: _transcriptController.text.trim(),
        fileSizeKB: fileSizeKB,
      );

      final success = await ref
          .read(storageServiceProvider)
          .saveRecording(recording);

      if (success && mounted) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved successfully')),
        );

        // Small delay to ensure the recording is saved
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate back to home screen and trigger refresh
        if (mounted) {
          if (!mounted) return;
          final navigator = Navigator.of(context);
          navigator.popUntil((route) => route.isFirst);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save recording')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error saving recording')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Context'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playback controls
            _buildPlaybackSection(),

            const SizedBox(height: 24),

            // Title input
            _buildTitleSection(),

            const SizedBox(height: 24),

            // Transcript section
            _buildTranscriptSection(),

            const SizedBox(height: 32),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              onPressed: _togglePlayback,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${widget.duration.inMinutes}:${(widget.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            if (_isPlaying)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Enter recording title',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transcript',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            ElevatedButton.icon(
              onPressed: _isTranscribing ? null : _transcribeRecording,
              icon: _isTranscribing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_isTranscribing ? 'Transcribing...' : 'Transcribe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Progress indicator (only show when transcribing)
        if (_isTranscribing) ...[
          LinearProgressIndicator(value: _transcriptionProgress),
          const SizedBox(height: 4),
          Text(
            _transcriptionStatus.isEmpty
                ? 'Processing...'
                : '$_transcriptionStatus ${(_transcriptionProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
        ],

        SizedBox(
          height: 200,
          child: TextField(
            controller: _transcriptController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Add notes or transcript here (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRecording,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }
}
