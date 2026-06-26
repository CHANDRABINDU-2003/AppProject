// Smoke test for AgriPulse.
//
// The app always boots into the shared LoginScreen (see main.dart), so this
// test just verifies that the app builds and the login UI renders. It does NOT
// tap "Log in", because that calls AuthService over the network — out of scope
// for a widget smoke test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agripulse/main.dart';

void main() {
  testWidgets('App boots into the login screen', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const AgriPulseApp());

    // The login screen shows the brand name and tagline.
    expect(find.text('AgriPulse'), findsOneWidget);
    expect(find.text('Smart Agriculture Ecosystem'), findsOneWidget);

    // Email + password fields and the two action buttons are present.
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
