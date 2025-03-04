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

  testWidgets('Onboarding screen is displayed on first launch', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isFirstLaunch: true)); // Przekazujemy wymagany parametr

    // Verify that the onboarding screen is displayed
    expect(find.text('Witaj w Trening & Dieta'), findsOneWidget); // Sprawdzenie AppBar
    expect(find.text('Witamy w aplikacji! Wypełnij poniższy formularz, aby rozpocząć.'), findsOneWidget); // Sprawdzenie tekstu powitalnego
    expect(find.widgetWithText(TextField, 'Nick'), findsOneWidget); // Sprawdzenie pola Nick
    expect(find.widgetWithText(ElevatedButton, 'Rozpocznij'), findsOneWidget); // Sprawdzenie przycisku

    // Opcjonalnie: Możesz zasymulować wypełnienie formularza i kliknięcie przycisku, ale to bardziej zaawansowane
  });
}
