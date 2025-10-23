import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Parachute home screen smoke test', (WidgetTester tester) async {
    // Build our app with ProviderScope wrapper (required for Riverpod)
    await tester.pumpWidget(
      const ProviderScope(
        child: ParachuteApp(),
      ),
    );

    // Wait for any async operations to complete
    await tester.pumpAndSettle();

    // Verify that the app loads without crashing
    // Note: The actual UI might be empty or show loading state initially
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
