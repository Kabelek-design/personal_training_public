import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_model.dart';
import '../api_service.dart';

class TrainingScreen extends StatefulWidget {
  final int? currentUserId; // Zachowuję jako opcjonalny, ale zawsze powinien być przekazany

  const TrainingScreen({super.key, this.currentUserId});

  @override
  _TrainingScreenState createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  int selectedWeek = 1;
  int? currentUserId; // Zmiana na int?, aby lepiej obsłużyć null
  String? planVersion; // Zmienna dla plan_version, może być null
  final ApiService _apiService = ApiService();
  List<TrainingPlan> _currentPlan = [];
  Map<int, Exercise> _exercisesMap = {};
  final Set<int> _completedSetIds = {}; // Zbiór ID ukończonych serii dla wszystkich tygodni
  bool _isLoading = true;
  String _errorMessage = '';
  Map<int, TextEditingController> amrapControllers = {};
  int? _expandedExerciseId;

  final Map<String, String> nameMappingStats = {
    "squats": "Przysiady",
    "dead_lift": "Martwy ciąg",
    "bench_press": "Wyciskanie leżąc",
  };

  @override
  void initState() {
    super.initState();
    currentUserId = widget.currentUserId; // Użyj przekazanego ID
    if (currentUserId == null) {
      _loadPreferences(); // Pobierz z SharedPreferences, jeśli nie przekazano
    } else {
      _loadData(); // Pobierz dane bezpośrednio, jeśli przekazano ID
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      currentUserId = prefs.getInt('currentUserId');
      if (currentUserId == null) {
        _errorMessage = 'Brak użytkownika. Utwórz konto.';
        _isLoading = false;

        return; // Zatrzymaj dalsze przetwarzanie, jeśli brak użytkownika
      }
      selectedWeek = prefs.getInt('selectedWeek') ?? 1;
      planVersion = prefs.getString('planVersion'); // Pobierz plan_version, może być null
      if (planVersion == null) {
        planVersion = "A"; // Domyślny plan, jeśli nie znaleziono

      }
      final completedIds = prefs.getStringList('completedSetIds') ?? [];
      _completedSetIds.clear(); // Wyczyść istniejące ID przed wczytaniem
      _completedSetIds.addAll(completedIds.map((id) => int.parse(id))); // Wczytaj zapisane ID ukończonych serii dla wszystkich tygodni


      // Wczytaj zapisane wartości AMRAP dla każdego seta
      amrapControllers.clear(); // Wyczyść istniejące kontrolery
    });
    _loadData();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (currentUserId != null) {
      await prefs.setInt('currentUserId', currentUserId!);
    }
    await prefs.setInt('selectedWeek', selectedWeek);
    await prefs.setString('planVersion', planVersion ?? "A");
    await prefs.setStringList('completedSetIds', _completedSetIds.map((id) => id.toString()).toList());


    // Zapisz aktualne wartości AMRAP dla każdego kontrolera, jeśli set jest ukończony
    for (var entry in amrapControllers.entries) {
      final setId = entry.key;
      final controller = entry.value;
      if (_completedSetIds.contains(setId) && controller.text.isNotEmpty) {
        final reps = int.tryParse(controller.text) ?? 0;
        await prefs.setInt('amrapReps_$setId', reps);

      }
    }

    for (var exercise in _exercisesMap.values) {
      await prefs.setDouble('oneRepMax_${exercise.id}', exercise.oneRepMax);
      print('Zapisano oneRepMax_${exercise.id}: ${exercise.oneRepMax}');
    }
  }

  int _getRequiredReps(int currentReps) {
    switch (currentReps) {
      case 6:
        return 12;
      case 4:
        return 8;
      case 2:
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _loadData() async {
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
      final prefs = await SharedPreferences.getInstance();
      if (planVersion == null) {
        planVersion = prefs.getString('planVersion') ?? "A";
      }

      final exercises = await _apiService.fetchExercises(userId: currentUserId!).timeout(const Duration(seconds: 10));
      final Map<int, Exercise> exercisesMap = {for (var ex in exercises) ex.id: ex};

      final plan = await _apiService.fetchTrainingPlan(currentUserId!, selectedWeek, planVersion!).timeout(const Duration(seconds: 10));

      // Pobierz plany dla wszystkich tygodni tylko raz, jeśli potrzebne do synchronizacji
      Map<int, List<TrainingPlan>> allPlans = {};
      for (int week = 1; week <= 6; week++) {
        final weekPlan = await _apiService.fetchTrainingPlan(currentUserId!, week, planVersion!).timeout(const Duration(seconds: 10));
        allPlans[week] = weekPlan;
      }

      // Inicjalizuj i synchronizuj kontrolery AMRAP z danymi z SharedPreferences dla aktualnego tygodnia
      for (var training in plan) {
        for (var set in training.sets) {
          if (set.isAMRAP) {
            if (!amrapControllers.containsKey(set.id)) {
              amrapControllers[set.id] = TextEditingController();
            }
            // Wczytaj zapisane wartości AMRAP z SharedPreferences
            final savedReps = prefs.getInt('amrapReps_${set.id}') ?? 0;
            if (_completedSetIds.contains(set.id) && savedReps > 0) {
              amrapControllers[set.id]?.text = savedReps.toString();
            } else if (!_completedSetIds.contains(set.id) && savedReps > 0) {
              amrapControllers[set.id]?.text = savedReps.toString();
            }
          }
        }
      }

      // Synchronizuj _completedSetIds z danymi z API i SharedPreferences dla wszystkich tygodni
      final currentSetIds = plan.expand((training) => training.sets).map((set) => set.id).toSet();
      final savedCompletedIds = prefs.getStringList('completedSetIds') ?? [];

      // Zachowaj wszystkie zapisane ID ukończonych serii, jeśli istnieją w którymkolwiek z planów
      for (String id in savedCompletedIds) {
        final setId = int.parse(id);
        bool setExistsInAnyWeek = allPlans.values.any((plans) => plans.any((training) => training.sets.any((set) => set.id == setId)));
        if (setExistsInAnyWeek && !_completedSetIds.contains(setId)) {
          _completedSetIds.add(setId);
        }
      }

      // Usuń tylko te ID, które nie istnieją w żadnym planie dla wszystkich tygodni
      _completedSetIds.removeWhere((setId) => !allPlans.values.any((plans) => plans.any((training) => training.sets.any((s) => s.id == setId))));

      setState(() {
        _exercisesMap = exercisesMap;
        _currentPlan = plan;
        _isLoading = false;
       
      });

      await _savePreferences();
    } catch (e) {
      setState(() {
        _errorMessage = 'Błąd ładowania danych: $e';
        _isLoading = false;

      });
    }
  }

  Future<void> _updateAmrap(int setId, int actualReps) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak użytkownika. Utwórz konto.')),
      );
      return;
    }

    try {
      final trainingSet = _currentPlan.expand((training) => training.sets).firstWhere(
            (set) => set.id == setId,
            orElse: () => throw Exception('Set o ID $setId nie znaleziono'),
          );

      final requiredReps = _getRequiredReps(trainingSet.reps);

    

      // Zawsze oznacz serię jako ukończoną, ale stosuj progresję tylko, jeśli liczba powtórzeń jest >= wymaganej
      setState(() {
        _completedSetIds.add(setId);
      });

      final controller = amrapControllers[setId];
      if (controller != null) {
        controller.text = actualReps.toString();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('amrapReps_$setId', actualReps);

      if (actualReps >= requiredReps) {
        // Zaktualizuj ciężar w API, dodając 2.5 kg lub 5 kg (zależnie od Twojej logiki w ApiService)
        await _apiService.updateAmrapWeights(
          userId: currentUserId!,
          setId: setId,
          actualReps: actualReps,
          weekNumber: selectedWeek,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Świetna robota! Zwiększyłeś ciężar na kolejny tydzień – czas na nowe wyzwanie!")),
        );
      } else {
        // Nie aktualizuj ciężaru, jeśli liczba powtórzeń jest mniejsza niż wymagana
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dobra robota! Pamiętaj to maraton nie sprint – dasz radę następnym razem!")),
        );
      }

      await _savePreferences();
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd aktualizacji wag: $e')),
      );
    }
  }

  Future<void> _completeTraining(int trainingId) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak użytkownika. Utwórz konto.')),
      );
      return;
    }

    try {
      final training = _currentPlan.firstWhere((t) => t.exerciseId == trainingId);
      setState(() {
        for (var set in training.sets) {
          _completedSetIds.add(set.id);
          if (set.isAMRAP) {
            final controller = amrapControllers[set.id];
            if (controller != null && controller.text.isNotEmpty) {
              final repsDone = int.tryParse(controller.text) ?? 0;
              if (repsDone > 0) {
                _completedSetIds.add(set.id); // Upewnij się, że set jest oznaczony jako ukończony
              }
            }
          }
        }
      });
      await _savePreferences();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trening zatwierdzony!")),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zatwierdzania treningu: $e')),
      );
      print('Błąd w _completeTraining: $e');
    }
  }

  @override
  void dispose() {
    amrapControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          margin: const EdgeInsets.all(8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Colors.black87, fontSize: 16),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.deepPurple),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
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
                  "Plan Treningowy",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.deepPurple.shade700,
                            Colors.deepPurple.shade400,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: DropdownButton<int>(
                        value: selectedWeek,
                        borderRadius: BorderRadius.circular(8),
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: Colors.deepPurple,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: [1, 2, 3, 4, 5, 6].map((week) {
                          return DropdownMenuItem(
                            value: week,
                            child: Text("Tydzień $week"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedWeek = val;
                            });
                            _savePreferences();
                            _loadData();
                          }
                        },
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
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: _currentPlan.length,
                          itemBuilder: (context, index) {
                            final training = _currentPlan[index];
                            final exercise = _exercisesMap[training.exerciseId];
                            final exerciseName = exercise != null
                                ? (nameMappingStats[exercise.name] ?? exercise.name)
                                : "Brak danych ćwiczenia";
                            bool allSetsDone = training.sets.every(
                                (set) => _completedSetIds.contains(set.id));
                            bool hasCompletedAmrap = training.sets.any((set) =>
                                set.isAMRAP && _completedSetIds.contains(set.id));

                            return Card(
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "$exerciseName - One rep max ${exercise?.oneRepMax.toStringAsFixed(1)} kg",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                    if (allSetsDone || (selectedWeek < 5 && hasCompletedAmrap))
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  ],
                                ),
                                initiallyExpanded: _expandedExerciseId == training.exerciseId,
                                onExpansionChanged: (isExpanded) {
                                  setState(() {
                                    _expandedExerciseId = isExpanded ? training.exerciseId : null;
                                  });
                                },
                                children: [
                                  ...training.sets.map((set) {
                                    bool isSetCompleted = _completedSetIds.contains(set.id);
                                    return ListTile(
                                      leading: set.isAMRAP
                                          ? Tooltip(
                                              message: "AMRAP - Wykonaj maksymalną liczbę powtórzeń",
                                              child: Icon(
                                                Icons.star,
                                                color: Colors.amber[700],
                                                size: 24,
                                              ),
                                            )
                                          : null,
                                      title: Text(
                                        "${set.reps} powt. - ${set.percentage}%",
                                        style: TextStyle(
                                          fontWeight: set.isAMRAP ? FontWeight.bold : FontWeight.normal,
                                          color: set.isAMRAP ? Colors.amber[900] : null,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Ciężar: ${set.weight.toStringAsFixed(1)} kg",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                          if (set.isAMRAP)
                                            Text(
                                              "Aby progresować, trzeba zrobić: ${_getRequiredReps(set.reps)}",
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: (selectedWeek != 5 && selectedWeek != 6 && set.isAMRAP)
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 60,
                                                  child: TextField(
                                                    controller: amrapControllers[set.id],
                                                    keyboardType: TextInputType.number,
                                                    enabled: !isSetCompleted, // Pole jest zablokowane, jeśli set jest ukończony
                                                    decoration: const InputDecoration(
                                                      hintText: "Powt.",
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    onChanged: (value) {
                                                      if (value.isEmpty || int.tryParse(value) == null) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text("Wpisz poprawną liczbę powtórzeń!")),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.check, color: Colors.green),
                                                  onPressed: isSetCompleted
                                                      ? null
                                                      : () {
                                                          String? text = amrapControllers[set.id]?.text;
                                                          int repsDone = text != null && text.isNotEmpty ? int.tryParse(text) ?? 0 : 0;
                                                          final requiredReps = _getRequiredReps(set.reps);

                                                          print('Debug - repsDone: $repsDone, set.reps: ${set.reps}, requiredReps: $requiredReps');

                                                          if (text == null || text.isEmpty || repsDone <= 0) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text("Wpisz poprawną liczbę powtórzeń!")),
                                                            );
                                                            return;
                                                          }

                                                          _updateAmrap(set.id, repsDone);
                                                        },
                                                ),
                                              ],
                                            )
                                          : null,
                                    );
                                  }).toList(),
                                  if (selectedWeek == 5 || selectedWeek == 6)
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: allSetsDone
                                          ? const SizedBox.shrink()
                                          : ElevatedButton.icon(
                                              onPressed: () => _completeTraining(training.exerciseId),
                                              icon: const Icon(Icons.check),
                                              label: const Text("Zatwierdź trening"),
                                            ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}