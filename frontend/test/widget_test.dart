// This is a basic Flutter widget test for CarryMate app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pick_o/main.dart';
import 'package:pick_o/services/mock_api_service.dart';

void main() {
  testWidgets('Registration screen smoke test', (WidgetTester tester) async {
    // Set initial mock values for SharedPreferences to avoid channel hanging
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame with the required provider.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MockApiService(),
        child: const PickOApp(),
      ),
    );

    // Rebuild after the async tryAutoLogin check settles
    await tester.pump();

    // Verify that PickO logo and registration fields are present on startup (in Login mode by default)
    expect(find.text('PickO'), findsOneWidget);

    expect(find.text('Secure Crowdshipping Logistics'), findsOneWidget);
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // Email/Username and Password fields
  });
}

