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

  final Map<int, double> repToPercentage = {
    1: 1.00, // 100%
    2: 0.95,
    3: 0.93,
    4: 0.90,
    5: 0.87,
    6: 0.85,
    7: 0.83,
    8: 0.80,
    9: 0.77,
    10: 0.75,
    11: 0.73,
    12: 0.70, // 70%
  };

  @override
  void initState() {
    super.initState();
    _fetchAllPlans();
    _fetchAvailableExercises();
  }
  

  Future<void> _fetchAllPlans() async {
    setState(() {
      isLoading = true;
    });
    try {
      plans = await apiService.getAllTrainingPlans(widget.currentUserId);
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
      final exercises =
          await apiService.fetchExercises(userId: widget.currentUserId);
      setState(() {
        availableExercises = exercises.where((exercise) {
          String apiName = nameMappingStats.entries
              .firstWhere(
                (entry) => entry.value == exercise.name,
                orElse: () => MapEntry(exercise.name, exercise.name),
              )
              .key;
          return !protectedExercises.contains(apiName);
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania dostępnych ćwiczeń: $e')),
      );
    }
  }

  // Funkcja do edycji planu treningowego
  Future<void> _editTrainingPlan(TrainingPlanSchedule plan) async {
    final nameController = TextEditingController(text: plan.name);
    final notesController = TextEditingController(text: plan.notes);
    DateTime selectedDate = plan.scheduledDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edytuj plan treningowy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa planu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      setDialogState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                  child:
                      Text('Data: ${selectedDate.toString().substring(0, 10)}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notatki',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                try {
                  final updateData = {
                    'name': nameController.text,
                    'scheduled_date':
                        selectedDate.toIso8601String().substring(0, 10),
                    'notes': notesController.text,
                  };

                  final updatedPlan = await apiService.updateTrainingPlan(
                    widget.currentUserId,
                    plan.id,
                    updateData,
                  );

                  setState(() {
                    final index = plans.indexWhere((p) => p.id == plan.id);
                    if (index != -1) {
                      plans[index] = updatedPlan;
                    }
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Plan zaktualizowany pomyślnie')),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Zapisz'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.deepPurple.shade600, width: 2),
                foregroundColor: Colors.deepPurple.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Anuluj'),
            ),
          ],
        ),
      ),
    );
  }

  // Funkcja do usuwania planu treningowego
  Future<void> _deleteTrainingPlan(TrainingPlanSchedule plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: Text('Czy na pewno chcesz usunąć plan "${plan.name}"?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Usuń'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.deepPurple.shade600, width: 2),
              foregroundColor: Colors.deepPurple.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await apiService.deleteTrainingPlan(widget.currentUserId, plan.id);
        setState(() {
          plans.removeWhere((p) => p.id == plan.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan usunięty pomyślnie')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    }
  }

  // Funkcja do edycji ćwiczenia w planie
  Future<void> _editExerciseInPlan(
      TrainingPlanSchedule plan, ExerciseSchedule exercise) async {
    final setsController =
        TextEditingController(text: exercise.sets.toString());
    final repsController =
        TextEditingController(text: exercise.reps.toString());
    final weightController =
        TextEditingController(text: exercise.weight.toString());
    final restTimeController =
        TextEditingController(text: exercise.restTime.toString());
    final notesController = TextEditingController(text: exercise.notes ?? '');

    final Exercise foundExercise = availableExercises.firstWhere(
      (e) => e.id == exercise.exerciseId,
      orElse: () => Exercise(
          id: 0, name: "Nieznane ćwiczenie", oneRepMax: 0, progressWeight: 0),
    );

    final exerciseName = foundExercise.name;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edytuj: $exerciseName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  if (value.isNotEmpty) {
                    int reps = int.tryParse(value) ?? 1;
                    // clamp do 1..12
                    if (reps < 1) reps = 1;
                    if (reps > 12) reps = 12;

                    // pobieramy mnożnik z mapy
                    final double multiplier = repToPercentage[reps] ?? 1.0;
                    final double suggestedWeight =
                        foundExercise.oneRepMax * multiplier;

                    setState(() {
                      weightController.text =
                          suggestedWeight.toStringAsFixed(1);
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
          ElevatedButton(
            onPressed: () async {
              try {
                final updateData = {
                  'sets': int.parse(setsController.text),
                  'reps': int.parse(repsController.text),
                  'weight': double.parse(weightController.text),
                  'rest_time': int.parse(restTimeController.text),
                  'notes': notesController.text.isEmpty
                      ? null
                      : notesController.text,
                };

                final updatedExercise = await apiService.updateExerciseInPlan(
                  widget.currentUserId,
                  plan.id,
                  exercise.id,
                  updateData,
                );

                setState(() {
                  final exerciseIndex =
                      plan.exercises!.indexWhere((e) => e.id == exercise.id);
                  if (exerciseIndex != -1) {
                    plan.exercises![exerciseIndex] = updatedExercise;
                  }
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ćwiczenie zaktualizowane pomyślnie')),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Zapisz'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.deepPurple.shade600, width: 2),
              foregroundColor: Colors.deepPurple.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }

  // Funkcja do usuwania ćwiczenia z planu
  Future<void> _deleteExerciseFromPlan(
      TrainingPlanSchedule plan, ExerciseSchedule exercise) async {
    final exerciseName = availableExercises
        .firstWhere(
          (e) => e.id == exercise.exerciseId,
          orElse: () => Exercise(
              id: 0,
              name: "Nieznane ćwiczenie",
              oneRepMax: 0,
              progressWeight: 0),
        )
        .name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: Text(
            'Czy na pewno chcesz usunąć ćwiczenie "$exerciseName" z planu?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Usuń'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.deepPurple.shade600, width: 2),
              foregroundColor: Colors.deepPurple.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await apiService.deleteExerciseFromPlan(
          widget.currentUserId,
          plan.id,
          exercise.id,
        );
        setState(() {
          plan.exercises!.removeWhere((e) => e.id == exercise.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ćwiczenie usunięte pomyślnie')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    }
  }

  // Zaktualizowana funkcja pokazująca szczegóły planu z opcjami edycji i usuwania
  void _showPlanDetails(TrainingPlanSchedule plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.deepPurple),
                            onPressed: () {
                              Navigator.pop(context); // Zamknij modal
                              _editTrainingPlan(plan);
                            },
                            tooltip: 'Edytuj plan',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context); // Zamknij modal
                              _deleteTrainingPlan(plan);
                            },
                            tooltip: 'Usuń plan',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Data: ${plan.scheduledDate.toString().substring(0, 10)}'),
                  Text('Notatki: ${plan.notes ?? "Brak"}'),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          "Ćwiczenia dodawane są z sekcji 'Wyniki' pamiętaj żeby jakieś dodać.",
                          style: TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 106, 106, 106)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ćwiczenia:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (plan.exercises == null || plan.exercises!.isEmpty)
                    const Text('Brak ćwiczeń')
                  else
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: plan.exercises!.length,
                      itemBuilder: (context, index) {
                        final exercise = plan.exercises![index];
                        String exerciseName =
                            "Ćwiczenie #${exercise.exerciseId}";
                        final foundExercise = availableExercises.firstWhere(
                          (e) => e.id == exercise.exerciseId,
                          orElse: () => Exercise(
                              id: 0,
                              name: "Nieznane",
                              oneRepMax: 0,
                              progressWeight: 0),
                        );
                        if (foundExercise.id != 0) {
                          exerciseName = foundExercise.name;
                        }

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            title: Text(exerciseName),
                            subtitle: Text(
                              'Serie: ${exercise.sets}, Powtórzenia: ${exercise.reps}, Waga: ${exercise.weight}kg, Odpoczynek: ${exercise.restTime}s',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (exercise.notes != null &&
                                    exercise.notes!.isNotEmpty)
                                  Tooltip(
                                    message: exercise.notes!,
                                    child: const Icon(Icons.info_outline),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () =>
                                      _editExerciseInPlan(plan, exercise),
                                  tooltip: 'Edytuj ćwiczenie',
                                  color: Colors.deepPurple,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  onPressed: () =>
                                      _deleteExerciseFromPlan(plan, exercise),
                                  tooltip: 'Usuń ćwiczenie',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                        iconColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    setDialogState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                child: Text(
                    'Wybierz datę: ${selectedDate.toString().substring(0, 10)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
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
                  final createdPlan = await apiService.createTrainingPlan(
                      widget.currentUserId, newPlan);
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Dodaj'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.deepPurple.shade600, width: 2),
                foregroundColor: Colors.deepPurple.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Anuluj'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExerciseToPlan(TrainingPlanSchedule plan) async {
    if (availableExercises.isEmpty) {
      await _fetchAvailableExercises();
      if (availableExercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Brak dostępnych ćwiczeń. Dodaj najpierw nowe ćwiczenia w sekcji Statystyki.')),
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
                      if (value != null && repsController.text.isNotEmpty) {
                        int reps = int.tryParse(repsController.text) ?? 1;
                        if (reps < 1) reps = 1;
                        if (reps > 12) reps = 12;
                        final multiplier = repToPercentage[reps] ?? 1.0;
                        final suggestedWeight = value.oneRepMax * multiplier;
                        weightController.text =
                            suggestedWeight.toStringAsFixed(1);
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
                    if (selectedExercise != null && value.isNotEmpty) {
                      int reps = int.tryParse(value) ?? 1;
                      if (reps < 1) reps = 1;
                      if (reps > 12) reps = 12;
                      final multiplier = repToPercentage[reps] ?? 1.0;
                      final suggestedWeight =
                          selectedExercise!.oneRepMax * multiplier;
                      setDialogState(() {
                        weightController.text =
                            suggestedWeight.toStringAsFixed(1);
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                    notes: notesController.text.isEmpty
                        ? null
                        : notesController.text,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Dodaj'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.deepPurple.shade600, width: 2),
                foregroundColor: Colors.deepPurple.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Anuluj'),
            ),
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
                      const Icon(Icons.calendar_today,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "Brak planów treningowych",
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
                          iconColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                                  const Icon(Icons.calendar_today,
                                      size: 18, color: Colors.deepPurple),
                                  const SizedBox(width: 8),
                                  Text(
                                    plan.scheduledDate
                                        .toString()
                                        .substring(0, 10),
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
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
        foregroundColor: Colors.white,
        tooltip: 'Dodaj nowy plan',
        child: const Icon(Icons.add),
      ),
    );
  }
}
