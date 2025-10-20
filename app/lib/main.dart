import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/spaces/screens/space_list_screen.dart';
import 'features/conversations/screens/conversation_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ParachuteApp(),
    ),
  );
}

class ParachuteApp extends StatelessWidget {
  const ParachuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parachute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SpaceListScreen(),
        '/conversations': (context) => const ConversationListScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
