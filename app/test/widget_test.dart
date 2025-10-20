import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Parachute home screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ParachuteApp());

    // Verify that the home screen shows our branding.
    expect(find.text('Parachute'), findsOneWidget);
    expect(find.text('Your open second brain'), findsOneWidget);
    expect(find.text('Powered by Claude AI'), findsOneWidget);
  });
}
