// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_training/main.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import do mockowania

void main() {
  // Mockowanie SharedPreferences, aby symulować pierwsze uruchomienie
  setUp(() async {
    SharedPreferences.setMockInitialValues({'isFirstLaunch': true});
  });

  testWidgets('Login selection screen is displayed on first launch', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(initialScreen: LoginSelectionScreen())); // Użyj nowy konstruktor

    // Verify that login selection screen is displayed
    expect(find.text('Progres Siłowy'), findsOneWidget);
    expect(find.text('Twój osobisty trener siłowy'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Zaloguj się'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Utwórz konto'), findsOneWidget);

    // Opcjonalnie: Możesz zasymulować kliknięcie przycisków
    // await tester.tap(find.widgetWithText(ElevatedButton, 'Zaloguj się'));
    // await tester.pumpAndSettle();
    // expect(find.byType(LoginScreen), findsOneWidget);
  });
}