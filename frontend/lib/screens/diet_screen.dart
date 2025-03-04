import 'package:flutter/material.dart';

class DietScreen extends StatelessWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dieta")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Tu dodamy logikę zapisywania posiłków
          },
          child: const Text("Dodaj posiłek"),
        ),
      ),
    );
  }
}
