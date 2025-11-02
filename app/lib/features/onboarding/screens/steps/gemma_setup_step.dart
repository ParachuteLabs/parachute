import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/title_generation_models.dart';
import 'package:app/core/widgets/gemma_model_download_card.dart';
import 'package:app/features/recorder/providers/service_providers.dart';
import 'package:app/core/providers/title_generation_provider.dart';

class GemmaSetupStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const GemmaSetupStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  ConsumerState<GemmaSetupStep> createState() => _GemmaSetupStepState();
}

class _GemmaSetupStepState extends ConsumerState<GemmaSetupStep> {
  TitleModelMode _selectedMode = TitleModelMode.local;
  GemmaModelType? _recommendedModel = GemmaModelType.gemma1b;
  bool _hasDownloadedModel = false;
  bool _hasHuggingFaceToken = false;
  final TextEditingController _tokenController = TextEditingController();
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _checkExistingModels();
    _loadHuggingFaceToken();
  }

  Future<void> _loadHuggingFaceToken() async {
    final storage = ref.read(storageServiceProvider);
    final token = await storage.getHuggingFaceToken();
    if (token != null && token.isNotEmpty && mounted) {
      setState(() {
        _hasHuggingFaceToken = true;
        _tokenController.text = token;
      });
    }
  }

  Future<void> _saveHuggingFaceToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    final storage = ref.read(storageServiceProvider);
    final success = await storage.saveHuggingFaceToken(token);

    if (mounted) {
      if (success) {
        setState(() => _hasHuggingFaceToken = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('HuggingFace token saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save token'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingModels() async {
    final gemmaManager = ref.read(gemmaModelManagerProvider);

    // Check each model type to see if any are already downloaded
    for (final modelType in GemmaModelType.values) {
      final isDownloaded = await gemmaManager.isModelDownloaded(modelType);
      if (isDownloaded && mounted) {
        setState(() {
          _hasDownloadedModel = true;
          _recommendedModel = modelType;
        });
        break; // Use the first downloaded model we find
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const Spacer(),
              TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
            ],
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            'Title Generation Setup',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            'Generate smart titles for your recordings',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(height: 24),

          // Mode selection
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  context,
                  mode: TitleModelMode.local,
                  title: 'Local',
                  subtitle: 'Private & Offline',
                  icon: Icons.download,
                  recommended: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  context,
                  mode: TitleModelMode.api,
                  title: 'Cloud',
                  subtitle: 'Gemini API',
                  icon: Icons.cloud,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Model selection (if local mode)
          if (_selectedMode == TitleModelMode.local) ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Download a Gemma model for AI-powered title generation. Gemma 1B is fastest.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // HuggingFace Token Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _hasHuggingFaceToken
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _hasHuggingFaceToken
                              ? Colors.green
                              : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _hasHuggingFaceToken
                                    ? Icons.check_circle
                                    : Icons.key,
                                color: _hasHuggingFaceToken
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'HuggingFace Token',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _hasHuggingFaceToken
                                      ? Colors.green[900]
                                      : Colors.orange[900],
                                ),
                              ),
                              if (_hasHuggingFaceToken) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'READY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gemma models require a free HuggingFace token. '
                            'Get yours at huggingface.co/settings/tokens',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasHuggingFaceToken
                                  ? Colors.green[900]
                                  : Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tokenController,
                                  obscureText: _obscureToken,
                                  decoration: InputDecoration(
                                    hintText: 'hf_...',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureToken
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _obscureToken = !_obscureToken,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _saveHuggingFaceToken,
                                icon: const Icon(Icons.save, size: 16),
                                label: const Text('Save'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Model cards
                    ...GemmaModelType.values.map(
                      (model) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GemmaModelDownloadCard(
                          modelType: model,
                          isPreferred: model == _recommendedModel,
                          onSetPreferred: () {
                            setState(() => _recommendedModel = model);
                          },
                          onDownloadComplete: () {
                            setState(() => _hasDownloadedModel = true);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You\'ll need a Google Gemini API key',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can add it later in Settings',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                // Save the selected mode
                await ref
                    .read(storageServiceProvider)
                    .setTitleGenerationMode(_selectedMode.name);
                if (_recommendedModel != null) {
                  await ref
                      .read(storageServiceProvider)
                      .setPreferredGemmaModel(_recommendedModel!.modelName);
                }
                widget.onNext();
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Helpful message if download is in progress
          if (_selectedMode == TitleModelMode.local && !_hasDownloadedModel)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Tip: You can continue setup while downloads finish in the background',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required TitleModelMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    bool recommended = false,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            if (recommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
