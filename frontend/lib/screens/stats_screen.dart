import 'package:flutter/material.dart';
import 'package:personal_training/api_service.dart';
import 'package:personal_training/models/training_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  final int? currentUserId;

  const StatsScreen({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ApiService _apiService = ApiService();
  List<Exercise> _exercises = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? currentUserId;

  final Set<String> protectedExercises = {"squats", "dead_lift", "bench_press"};
  final Map<String, String> nameMappingStats = {
    "squats": "Przysiady",
    "dead_lift": "Martwy ciąg",
    "bench_press": "Wyciskanie leżąc",
  };

  @override
  void initState() {
    super.initState();
    _loadUserIdAndExercises();
  }

  Future<void> _loadUserIdAndExercises() async {
    final prefs = await SharedPreferences.getInstance();
    int? loadedUserId = widget.currentUserId ?? prefs.getInt('currentUserId');
    if (loadedUserId == null) {
      loadedUserId = 1;
      await prefs.setInt('currentUserId', loadedUserId);
    }
    setState(() {
      currentUserId = loadedUserId;
    });
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    if (currentUserId == null) {
      setState(() {
        _errorMessage = 'Brak użytkownika. Utwórz konto.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final exercises = await _apiService.fetchExercises(userId: currentUserId);
      setState(() {
        _exercises = exercises.map((exercise) {
          return Exercise(
            id: exercise.id,
            name: nameMappingStats[exercise.name] ?? exercise.name,
            oneRepMax: exercise.oneRepMax,
            progressWeight: exercise.progressWeight,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _editOneRepMax(Exercise exercise) async {
  final TextEditingController controller =
      TextEditingController(text: exercise.oneRepMax.toString());

  bool? confirm = await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Nowy 1RM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Zmiana wartości 1RM spowoduje wyczyszczenie progresji. Czy na pewno chcesz kontynuować?",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nowy 1RM (kg)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Zatwierdź'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: Colors.deepPurple.shade600, width: 2), // Border fioletowy
              foregroundColor: Colors.deepPurple.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Anuluj'),
          ),
        ],
      );
    },
  );

  if (confirm == true) {
    double? newOneRepMax = double.tryParse(controller.text);
    if (newOneRepMax == null || newOneRepMax <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Niepoprawna wartość 1RM!')),
      );
      return;
    }

    try {
      String apiName = nameMappingStats.entries
          .firstWhere((entry) => entry.value == exercise.name,
              orElse: () => MapEntry(exercise.name, exercise.name))
          .key;
      await _apiService.updateExercise(
        currentUserId!,
        exercise.id,
        newOneRepMax,
        apiName,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('oneRepMaxChanged_${exercise.id}', true); // Zapis informacji o zmianie 1RM dla konkretnego ćwiczenia
      await prefs.setBool('oneRepMaxChanged', true); // Globalna flaga dla wszystkich ćwiczeń
      await prefs.setInt('changedExerciseId', exercise.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1RM zaktualizowane!')),
      );
      _loadExercises();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd aktualizacji: $e')),
      );
    }
  }
}

  Future<void> _addExercise() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController maxController = TextEditingController();

    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Dodaj nowe ćwiczenie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa ćwiczenia',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '1RM (kg)',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Dodaj'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: Colors.deepPurple.shade600, width: 2), // Border fioletowy
                foregroundColor: Colors.deepPurple.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Anuluj'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      String name = nameController.text.trim();
      double? oneRepMax = double.tryParse(maxController.text);

      if (name.isEmpty || oneRepMax == null || oneRepMax <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Niepoprawne dane ćwiczenia!')),
        );
        return;
      }

      try {
        String apiName = nameMappingStats.entries
            .firstWhere((entry) => entry.value == name,
                orElse: () => MapEntry(name, name))
            .key;
        await _apiService.addExercise(currentUserId!, apiName, oneRepMax);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodano nowe ćwiczenie!')),
        );
        _loadExercises();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd dodawania ćwiczenia: $e')),
        );
      }
    }
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    String apiName = nameMappingStats.entries
        .firstWhere((entry) => entry.value == exercise.name,
            orElse: () => MapEntry(exercise.name, exercise.name))
        .key;
    if (protectedExercises.contains(apiName)) return;

    try {
      await _apiService.deleteExercise(currentUserId!, exercise.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ćwiczenie usunięte!')),
      );
      _loadExercises();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd usuwania ćwiczenia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final basicExercises = _exercises
        .where((ex) => protectedExercises.contains(nameMappingStats.entries
            .firstWhere((entry) => entry.value == ex.name,
                orElse: () => MapEntry(ex.name, ex.name))
            .key))
        .toList();
    final additionalExercises = _exercises
        .where((ex) => !protectedExercises.contains(nameMappingStats.entries
            .firstWhere((entry) => entry.value == ex.name,
                orElse: () => MapEntry(ex.name, ex.name))
            .key))
        .toList();

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: Colors.deepPurple,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepPurple,
          accentColor: Colors.green,
          backgroundColor: Colors.grey[100],
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade700,
                    Colors.deepPurple.shade300,
                  ],
                ),
              ),
              child: AppBar(
                title: const Text(
                  "Statystyki",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text('Nowe ćwiczenie'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        elevation: 0,
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) {
                            if (states.contains(WidgetState.pressed)) {
                              return Colors.deepPurple.shade600;
                            }
                            return Colors.transparent;
                          },
                        ),
                        overlayColor:
                            WidgetStateProperty.all(Colors.deepPurple.withOpacity(0.1)),
                      ).copyWith(
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      ...basicExercises
                          .map((exercise) => Card(
                                child: InkWell(
                                  onTap: () => _editOneRepMax(exercise), // Cała karta klikalna do edycji
                                  child: ListTile(
                                    title: Text(
                                      exercise.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '1RM: ${exercise.oneRepMax} kg (+${exercise.progressWeight} kg progresji)',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.deepPurple),
                                      onPressed: () => _editOneRepMax(exercise), // Zachowaj ikonkę do edycji
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                      if (additionalExercises.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(
                            thickness: 2,
                            color: Colors.grey,
                          ),
                        ),
                      ...additionalExercises
                          .map((exercise) => Card(
                                child: InkWell(
                                  onTap: () => _editOneRepMax(exercise), // Cała karta klikalna do edycji
                                  child: ListTile(
                                    title: Text(
                                      exercise.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '1RM: ${exercise.oneRepMax} kg (+${exercise.progressWeight} kg progresji)',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.deepPurple), // Zmiana koloru na Colors.deepPurple
                                          onPressed: () => _editOneRepMax(exercise),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => _deleteExercise(exercise),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ],
                  ),
      ),
    );
  }
}