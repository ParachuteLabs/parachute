import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/smollm_models.dart';
import '../providers/title_generation_provider.dart';

class SmolLMModelDownloadCard extends ConsumerStatefulWidget {
  final SmolLMModelType modelType;
  final bool isPreferred;
  final VoidCallback onSetPreferred;

  const SmolLMModelDownloadCard({
    super.key,
    required this.modelType,
    required this.isPreferred,
    required this.onSetPreferred,
  });

  @override
  ConsumerState<SmolLMModelDownloadCard> createState() => _SmolLMModelDownloadCardState();
}

class _SmolLMModelDownloadCardState extends ConsumerState<SmolLMModelDownloadCard> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    _listenToDownloadProgress();
  }

  Future<void> _checkDownloadStatus() async {
    final modelManager = ref.read(smollmModelManagerProvider);
    final isDownloaded = await modelManager.isModelDownloaded(widget.modelType);
    if (mounted) {
      setState(() => _isDownloaded = isDownloaded);
    }
  }

  void _listenToDownloadProgress() {
    final modelManager = ref.read(smollmModelManagerProvider);
    modelManager.progressStream.listen((progress) {
      if (progress.model == widget.modelType && mounted) {
        setState(() {
          _isDownloading = progress.state == ModelDownloadState.downloading;
          _isDownloaded = progress.state == ModelDownloadState.downloaded;
          _downloadProgress = progress.progress;
        });
      }
    });
  }

  Future<void> _downloadModel() async {
    try {
      final modelManager = ref.read(smollmModelManagerProvider);
      await modelManager.downloadModel(widget.modelType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.modelType.displayName} downloaded!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isDownloaded ? Icons.check_circle : Icons.cloud_download, 
                     color: _isDownloaded ? Colors.green : Colors.grey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.modelType.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.modelType.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text('Size: ${widget.modelType.sizeInMB} MB', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _downloadProgress),
              Text('${(_downloadProgress * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            if (!_isDownloaded && !_isDownloading)
              ElevatedButton.icon(
                onPressed: _downloadModel,
                icon: const Icon(Icons.cloud_download, size: 18),
                label: const Text('Download'),
              ),
          ],
        ),
      ),
    );
  }
}
