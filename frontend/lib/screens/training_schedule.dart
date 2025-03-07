import 'package:flutter/material.dart';
import 'package:personal_training/api_service.dart';
import 'package:personal_training/models/training_schedule.dart';
import 'package:personal_training/models/training_model.dart';

class TrainingScheduleScreen extends StatefulWidget {
  final int currentUserId;

  const TrainingScheduleScreen({super.key, required this.currentUserId});

  @override
  _TrainingScheduleScreenState createState() => _TrainingScheduleScreenState();
}

class _TrainingScheduleScreenState extends State<TrainingScheduleScreen> {
  final ApiService apiService = ApiService();
  List<TrainingPlanSchedule> plans = [];
  List<Exercise> availableExercises = [];
  bool isLoading = false;
  final Set<String> protectedExercises = {"squats", "dead_lift", "bench_press"};
  final Map<String, String> nameMappingStats = {
    "squats": "Przysiady",
    "dead_lift": "Martwy ciąg",
    "bench_press": "Wyciskanie leżąc",
  };

  @override
  void initState() {
    super.initState();
    _fetchPlansForCurrentWeek();
    _fetchAvailableExercises();
  }

  Future<void> _fetchPlansForCurrentWeek() async {
    setState(() {
      isLoading = true;
    });
    try {
      print('Pobieranie planów dla userId: ${widget.currentUserId}');
      plans = await apiService.getTrainingPlansForCurrentWeek(widget.currentUserId);
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd: $e')),
      );
    }
  }

  Future<void> _fetchAvailableExercises() async {
    try {
      final exercises = await apiService.fetchExercises(userId: widget.currentUserId);
      setState(() {
        // Filtrujemy ćwiczenia, wykluczając chronione (squats, dead_lift, bench_press)
        availableExercises = exercises.where((exercise) {
          // Znajdź nazwę API dla ćwiczenia
          String apiName = nameMappingStats.entries
              .firstWhere((entry) => entry.value == exercise.name,
                  orElse: () => MapEntry(exercise.name, exercise.name))
              .key;
          // Zwracamy true tylko dla ćwiczeń, które NIE są chronione
          return !protectedExercises.contains(apiName);
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania dostępnych ćwiczeń: $e')),
      );
    }
  }

  Future<void> _addTrainingPlan() async {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dodaj nowy plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nazwa planu'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    setDialogState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                child: Text('Wybierz datę: ${selectedDate.toString().substring(0, 10)}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final newPlan = TrainingPlanSchedule(
                    id: 0,
                    userId: widget.currentUserId,
                    name: nameController.text.isEmpty
                        ? "Nowy plan ${selectedDate.toString().substring(0, 10)}"
                        : nameController.text,
                    scheduledDate: selectedDate,
                    notes: "Nowy plan treningowy",
                    createdAt: DateTime.now(),
                    exercises: [],
                  );
                  final createdPlan = await apiService.createTrainingPlan(widget.currentUserId, newPlan);
                  setState(() {
                    plans.add(createdPlan);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan dodany pomyślnie')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd: $e')),
                  );
                }
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExerciseToPlan(TrainingPlanSchedule plan) async {
    // Upewnij się, że mamy dostępne ćwiczenia
    if (availableExercises.isEmpty) {
      await _fetchAvailableExercises();
      if (availableExercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak dostępnych ćwiczeń. Dodaj najpierw nowe ćwiczenia w sekcji Statystyki.')),
        );
        return;
      }
    }

    Exercise? selectedExercise;
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');
    final weightController = TextEditingController();
    final restTimeController = TextEditingController(text: '90');
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dodaj ćwiczenie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown do wyboru ćwiczenia
                DropdownButtonFormField<Exercise>(
                  decoration: const InputDecoration(
                    labelText: 'Wybierz ćwiczenie',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Wybierz ćwiczenie'),
                  value: selectedExercise,
                  items: availableExercises.map((exercise) {
                    return DropdownMenuItem<Exercise>(
                      value: exercise,
                      child: Text(exercise.name),
                    );
                  }).toList(),
                  onChanged: (Exercise? value) {
                    setDialogState(() {
                      selectedExercise = value;
                      // Automatycznie ustaw sugerowaną wagę na podstawie 1RM i ilości powtórzeń
                      if (value != null && repsController.text.isNotEmpty) {
                        int reps = int.tryParse(repsController.text) ?? 10;
                        // Prosta formuła obliczająca sugerowaną wagę na podstawie 1RM i ilości powtórzeń
                        // Można dostosować tę formułę do potrzeb
                        double suggestedWeight = value.oneRepMax * (1 - (0.025 * reps));
                        weightController.text = suggestedWeight.toStringAsFixed(1);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: setsController,
                  decoration: const InputDecoration(
                    labelText: 'Liczba serii',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: repsController,
                  decoration: const InputDecoration(
                    labelText: 'Liczba powtórzeń',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    // Aktualizuj sugerowaną wagę przy zmianie liczby powtórzeń
                    if (selectedExercise != null && value.isNotEmpty) {
                      int reps = int.tryParse(value) ?? 10;
                      double suggestedWeight = selectedExercise!.oneRepMax * (1 - (0.025 * reps));
                      setDialogState(() {
                        weightController.text = suggestedWeight.toStringAsFixed(1);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: 'Waga (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: restTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Czas odpoczynku (s)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notatki',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple.shade600,
              ),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedExercise == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wybierz ćwiczenie!')),
                  );
                  return;
                }

                try {
                  final newExercise = ExerciseSchedule(
                    id: 0,
                    trainingPlanId: plan.id,
                    exerciseId: selectedExercise!.id,
                    sets: int.parse(setsController.text),
                    reps: int.parse(repsController.text),
                    weight: double.parse(weightController.text),
                    restTime: int.parse(restTimeController.text),
                    notes: notesController.text.isEmpty ? null : notesController.text,
                  );
                  final addedExercise = await apiService.addExerciseToPlan(
                    widget.currentUserId,
                    plan.id,
                    newExercise,
                  );
                  setState(() {
                    plan.exercises ??= [];
                    plan.exercises!.add(addedExercise);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ćwiczenie dodane pomyślnie')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlanDetails(TrainingPlanSchedule plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Pozwala na większy modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Data: ${plan.scheduledDate.toString().substring(0, 10)}'),
            Text('Notatki: ${plan.notes ?? "Brak"}'),
            const SizedBox(height: 16),
            const Text('Ćwiczenia:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (plan.exercises == null || plan.exercises!.isEmpty)
              const Text('Brak ćwiczeń')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plan.exercises!.length,
                  itemBuilder: (context, index) {
                    final exercise = plan.exercises![index];
                    // Znajdź nazwę ćwiczenia na podstawie exerciseId
                    String exerciseName = "Ćwiczenie #${exercise.exerciseId}";
                    final foundExercise = availableExercises.firstWhere(
                      (e) => e.id == exercise.exerciseId,
                      orElse: () => Exercise(id: 0, name: "Nieznane", oneRepMax: 0, progressWeight: 0),
                    );
                    if (foundExercise.id != 0) {
                      exerciseName = foundExercise.name;
                    }
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(exerciseName),
                        subtitle: Text(
                          'Serie: ${exercise.sets}, Powtórzenia: ${exercise.reps}, Waga: ${exercise.weight}kg, Odpoczynek: ${exercise.restTime}s',
                        ),
                        trailing: exercise.notes != null && exercise.notes!.isNotEmpty
                            ? Tooltip(
                                message: exercise.notes!,
                                child: const Icon(Icons.info_outline),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addExerciseToPlan(plan),
                icon: const Icon(Icons.fitness_center),
                label: const Text('Dodaj ćwiczenie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 30), // Dodatkowa przestrzeń na dole
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                "Harmonogram Treningowy",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "Brak planów na ten tydzień",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addTrainingPlan,
                        icon: const Icon(Icons.add),
                        label: const Text("Dodaj plan treningowy"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _showPlanDetails(plan),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.deepPurple),
                                  const SizedBox(width: 8),
                                  Text(
                                    plan.scheduledDate.toString().substring(0, 10),
                                    style: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Ćwiczeń: ${plan.exercises?.length ?? 0}',
                                      style: TextStyle(
                                        color: Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTrainingPlan,
        backgroundColor: Colors.deepPurple.shade600,
        child: const Icon(Icons.add),
        tooltip: 'Dodaj nowy plan',
      ),
    );
  }
}