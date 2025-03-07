import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: TrainingPlanScreen());
  }
}

class TrainingPlanScreen extends StatefulWidget {
  @override
  _TrainingPlanScreenState createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  DateTime _selectedDay = DateTime.now();
  String? _mainExercise;
  List<Map<String, dynamic>> _hypertrophyExercises = [];

  final List<String> _mainExercises = [
    'Przysiad',
    'Martwy ciąg',
    'Wyciskanie',
  ];

  void _addHypertrophyExercise() {
    setState(() {
      _hypertrophyExercises.add({'name': '', 'sets': '', 'weight': ''});
    });
  }

  Future<void> _savePlan() async {
    if (_mainExercise == null || _hypertrophyExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wypełnij wszystkie pola!')),
      );
      return;
    }

    final url = Uri.parse('http://twoj-vps/api/training-plan');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': _selectedDay.toIso8601String().split('T')[0],
        'main_exercise': _mainExercise,
        'hypertrophy_exercises': _hypertrophyExercises,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan zapisany!')),
      );
      setState(() {
        _mainExercise = null;
        _hypertrophyExercises.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd: ${response.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plan Treningowy')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kalendarz
            TableCalendar(
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2026, 12, 31),
              focusedDay: _selectedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() => _selectedDay = selectedDay);
              },
            ),
            SizedBox(height: 20),
            // Główne ćwiczenie
            Text('Główne ćwiczenie', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _mainExercise,
              hint: Text('Wybierz ćwiczenie'),
              items: _mainExercises
                  .map((exercise) => DropdownMenuItem(
                        value: exercise,
                        child: Text(exercise),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _mainExercise = value),
            ),
            SizedBox(height: 20),
            // Ćwiczenia hipertroficzne
            Text('Ćwiczenia hipertroficzne', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._hypertrophyExercises.map((exercise) {
              int index = _hypertrophyExercises.indexOf(exercise);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Nazwa'),
                        onChanged: (value) =>
                            _hypertrophyExercises[index]['name'] = value,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Serie'),
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            _hypertrophyExercises[index]['sets'] = value,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Ciężar (kg)'),
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            _hypertrophyExercises[index]['weight'] = value,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addHypertrophyExercise,
              child: Text('Dodaj kolejne ćwiczenie'),
            ),
            SizedBox(height: 20),
            // Przycisk zapisu
            ElevatedButton(
              onPressed: _savePlan,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.green, // Kolor dla wyróżnienia
              ),
              child: Text('Zapisz plan dnia', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}