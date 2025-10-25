import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/recorder/models/whisper_models.dart';
import 'package:app/features/recorder/providers/service_providers.dart';

/// Widget for displaying and managing a Whisper model download
class WhisperModelDownloadCard extends ConsumerStatefulWidget {
  final WhisperModelType modelType;
  final bool isPreferred;
  final VoidCallback onSetPreferred;

  const WhisperModelDownloadCard({
    super.key,
    required this.modelType,
    required this.isPreferred,
    required this.onSetPreferred,
  });

  @override
  ConsumerState<WhisperModelDownloadCard> createState() =>
      _WhisperModelDownloadCardState();
}

class _WhisperModelDownloadCardState
    extends ConsumerState<WhisperModelDownloadCard> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isDeleting = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    _listenToDownloadProgress();
  }

  Future<void> _checkDownloadStatus() async {
    final modelManager = ref.read(whisperModelManagerProvider);
    final isDownloaded = await modelManager.isModelDownloaded(widget.modelType);
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  void _listenToDownloadProgress() {
    final modelManager = ref.read(whisperModelManagerProvider);
    modelManager.progressStream.listen((progress) {
      if (progress.model == widget.modelType && mounted) {
        setState(() {
          switch (progress.state) {
            case ModelDownloadState.downloading:
              _isDownloading = true;
              _downloadProgress = progress.progress;
              _errorMessage = null;
              break;
            case ModelDownloadState.downloaded:
              _isDownloading = false;
              _isDownloaded = true;
              _downloadProgress = 1.0;
              _errorMessage = null;
              break;
            case ModelDownloadState.failed:
              _isDownloading = false;
              _errorMessage = progress.error ?? 'Download failed';
              break;
            case ModelDownloadState.notDownloaded:
              _isDownloaded = false;
              _isDownloading = false;
              _downloadProgress = 0.0;
              break;
          }
        });
      }
    });
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final modelManager = ref.read(whisperModelManagerProvider);
      await modelManager.downloadModel(widget.modelType);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.modelType.displayName} model downloaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text(
          'Are you sure you want to delete the ${widget.modelType.displayName} model? '
          'This will free up ${widget.modelType.formattedSize} of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final modelManager = ref.read(whisperModelManagerProvider);
      final success = await modelManager.deleteModel(widget.modelType);

      if (mounted) {
        if (success) {
          setState(() {
            _isDownloaded = false;
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.modelType.displayName} model deleted'),
            ),
          );
        } else {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete model'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: widget.isPreferred ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isPreferred
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.modelType.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.isPreferred)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.modelType.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.modelType.formattedSize,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(),
              ],
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 4),
              Text(
                'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_isDownloaded && !_isDownloading)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _downloadModel,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_isDownloaded) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          widget.isPreferred ? null : widget.onSetPreferred,
                      icon: Icon(
                        widget.isPreferred
                            ? Icons.check
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      label: Text(widget.isPreferred ? 'Active' : 'Use This'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isPreferred
                            ? Colors.green
                            : Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _deleteModel,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_isDownloaded) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 32);
    } else {
      return Icon(Icons.cloud_download, color: Colors.grey[400], size: 32);
    }
  }
}
