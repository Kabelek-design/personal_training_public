import 'package:flutter/material.dart';
import 'package:personal_training/api_service.dart';
import 'package:personal_training/models/training_schedule.dart';

class TrainingScheduleScreen extends StatefulWidget {
  final int currentUserId;

  const TrainingScheduleScreen({super.key, required this.currentUserId});

  @override
  _TrainingScheduleScreenState createState() => _TrainingScheduleScreenState();
}

class _TrainingScheduleScreenState extends State<TrainingScheduleScreen> {
  final ApiService apiService = ApiService();
  List<TrainingPlanSchedule> plans = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPlansForCurrentWeek();
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
    final exerciseIdController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final weightController = TextEditingController();
    final restTimeController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj ćwiczenie'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: exerciseIdController,
                decoration: const InputDecoration(labelText: 'ID Ćwiczenia'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: setsController,
                decoration: const InputDecoration(labelText: 'Liczba serii'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Liczba powtórzeń'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Waga (kg)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: restTimeController,
                decoration: const InputDecoration(labelText: 'Czas odpoczynku (s)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notatki'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final newExercise = ExerciseSchedule(
                  id: 0,
                  trainingPlanId: plan.id,
                  exerciseId: int.parse(exerciseIdController.text),
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
                  // Poprawiono inicjalizację listy exercises
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
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  void _showPlanDetails(TrainingPlanSchedule plan) {
    showModalBottomSheet(
      context: context,
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
              ...plan.exercises!.map((exercise) => ListTile(
                    title: Text('Ćwiczenie ID: ${exercise.exerciseId}'),
                    subtitle: Text(
                        'Serie: ${exercise.sets}, Powtórzenia: ${exercise.reps}, Waga: ${exercise.weight}kg'),
                  )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _addExerciseToPlan(plan),
              child: const Text('Dodaj ćwiczenie'),
            ),
          ],
        ),
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Harmonogram Treningowy"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
              ? const Center(child: Text("Brak planów na ten tydzień"))
              : ListView.builder(
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return ListTile(
                      title: Text(plan.name),
                      subtitle: Text(
                        '${plan.scheduledDate.toString().substring(0, 10)} | Ćwiczeń: ${plan.exercises?.length ?? 0}',
                      ),
                      onTap: () => _showPlanDetails(plan),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTrainingPlan,
        child: const Icon(Icons.add),
        tooltip: 'Dodaj pojedynczy plan',
      ),
    );
  }
}