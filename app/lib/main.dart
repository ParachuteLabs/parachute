import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opus_dart/opus_dart.dart' as opus_dart;
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'core/theme/app_theme.dart';
import 'core/providers/feature_flags_provider.dart';
import 'features/spaces/screens/space_list_screen.dart';
import 'features/recorder/screens/home_screen.dart' as recorder;
import 'features/files/screens/file_browser_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Disable verbose FlutterBluePlus logs (reduces spam from onCharacteristicChanged)
  FlutterBluePlus.setLogLevel(LogLevel.none, color: false);

  // Initialize Opus codec for audio decoding (required for Omi device recordings)
  try {
    debugPrint('[Main] Loading Opus library...');

    DynamicLibrary library;

    // opus_flutter doesn't support macOS, so we need to manually load the library
    if (Platform.isMacOS) {
      debugPrint('[Main] Platform: macOS - loading Opus library manually');

      // Try to load from bundled library first, then fall back to system paths
      final possiblePaths = [
        '@executable_path/../Frameworks/libopus.dylib', // Bundled with app
        'libopus.dylib', // Relative to app
      ];

      DynamicLibrary? loadedLib;
      for (final path in possiblePaths) {
        try {
          debugPrint('[Main] Trying to load Opus from: $path');
          loadedLib = DynamicLibrary.open(path);
          debugPrint('[Main] ✅ Successfully loaded Opus from: $path');
          break;
        } catch (e) {
          debugPrint('[Main] Failed to load from $path: $e');
        }
      }

      if (loadedLib == null) {
        throw Exception(
          'Could not find libopus.dylib in app bundle. The library should be bundled with the app.',
        );
      }

      library = loadedLib;
    } else {
      // Use opus_flutter for supported platforms (Android, iOS, Windows)
      library = await opus_flutter.load() as DynamicLibrary;
      debugPrint('[Main] Opus library loaded via opus_flutter: $library');
    }

    debugPrint('[Main] Initializing Opus codec...');
    opus_dart.initOpus(library);
    debugPrint('[Main] ✅ Opus codec initialized successfully');

    // Verify initialization by getting version
    try {
      final version = opus_dart.getOpusVersion();
      debugPrint('[Main] Opus version: $version');
    } catch (e) {
      debugPrint('[Main] ⚠️  Warning: Could not get Opus version: $e');
    }
  } catch (e, stackTrace) {
    debugPrint('[Main] ❌ Failed to initialize Opus codec: $e');
    debugPrint('[Main] Stack trace: $stackTrace');
    // Continue anyway - only affects Omi device recordings with Opus codec
  }

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error
    FlutterError.presentError(details);

    // In production, you could send to crash reporting service
    if (kReleaseMode) {
      // TODO: Send to crash reporting (Firebase Crashlytics, Sentry, etc.)
      debugPrint('Error caught in release mode: ${details.exception}');
    }
  };

  // Catch errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');

    // In production, send to crash reporting
    if (kReleaseMode) {
      // TODO: Send to crash reporting
    }

    return true; // Prevents error from propagating
  };

  runApp(const ProviderScope(child: ParachuteApp()));
}

class ParachuteApp extends StatelessWidget {
  const ParachuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parachute',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex =
      1; // Start on Recorder tab (index 1 when AI Chat enabled, index 0 when disabled)

  @override
  Widget build(BuildContext context) {
    final aiChatEnabledAsync = ref.watch(aiChatEnabledNotifierProvider);

    return aiChatEnabledAsync.when(
      data: (aiChatEnabled) {
        // Build screens list based on feature flags
        final screens = <Widget>[];
        final navItems = <BottomNavigationBarItem>[];

        int recorderIndex = 0;
        int filesIndex = 1;

        // Add AI Chat tab if enabled
        if (aiChatEnabled) {
          screens.add(const SpaceListScreen());
          navItems.add(
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'AI Chat',
              tooltip: 'AI Chat with Claude',
            ),
          );
          recorderIndex = 1;
          filesIndex = 2;
        }

        // Always show Recorder tab (core feature)
        screens.add(const recorder.HomeScreen());
        navItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.mic_none),
            activeIcon: Icon(Icons.mic),
            label: 'Recorder',
            tooltip: 'Voice Recorder',
          ),
        );

        // Always show Files tab
        screens.add(const FileBrowserScreen());
        navItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Files',
            tooltip: 'Browse Files',
          ),
        );

        // Ensure selected index is valid
        if (_selectedIndex >= screens.length) {
          _selectedIndex = recorderIndex; // Default to recorder
        }

        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: navItems,
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) {
        // On error, show a minimal interface with just Recorder
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: const [recorder.HomeScreen(), FileBrowserScreen()],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex.clamp(0, 1),
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.mic_none),
                activeIcon: Icon(Icons.mic),
                label: 'Recorder',
                tooltip: 'Voice Recorder',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                activeIcon: Icon(Icons.folder),
                label: 'Files',
                tooltip: 'Browse Files',
              ),
            ],
          ),
        );
      },
    );
  }
}
