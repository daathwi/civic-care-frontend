import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grievance_app/main.dart';

void main() {
  testWidgets('CivicCare app login and navigation test', (WidgetTester tester) async {
    // Build app, trigger first frame.
    await tester.pumpWidget(const ProviderScope(child: CivicCareApp()));

    // Verify that we are on the LoginScreen.
    expect(find.text('Sign In'), findsOneWidget);

    // Enter credentials.
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.enterText(find.byType(TextField).last, 'password');

    // Tap Sign In.
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify Dashboard is now the home screen.
    expect(find.text('Overview'), findsOneWidget);

    // Tap on Community tab.
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // Tap on History tab.
    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();
  });
}
