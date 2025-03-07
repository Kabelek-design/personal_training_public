class TrainingPlanSchedule {
  final int id;
  final int userId;
  final String name;
  final DateTime scheduledDate;
  final String? notes;
  final DateTime createdAt;
  List<ExerciseSchedule>? exercises; // Usunięto 'final'

  TrainingPlanSchedule({
    required this.id,
    required this.userId,
    required this.name,
    required this.scheduledDate,
    this.notes,
    required this.createdAt,
    this.exercises,
  });

  factory TrainingPlanSchedule.fromJson(Map<String, dynamic> json) {
    return TrainingPlanSchedule(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      scheduledDate: DateTime.parse(json['scheduled_date']),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      exercises: json['exercises'] != null
          ? (json['exercises'] as List).map((e) => ExerciseSchedule.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'scheduled_date': scheduledDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'exercises': exercises?.map((e) => e.toJson()).toList(),
    };
  }
}

class ExerciseSchedule {
  final int id;
  final int trainingPlanId;
  final int exerciseId;
  final int sets;
  final int reps;
  final double weight;
  final int? restTime;
  final String? notes;

  ExerciseSchedule({
    required this.id,
    required this.trainingPlanId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weight,
    this.restTime,
    this.notes,
  });

  factory ExerciseSchedule.fromJson(Map<String, dynamic> json) {
    return ExerciseSchedule(
      id: json['id'] as int,
      trainingPlanId: json['training_plan_id'] as int,
      exerciseId: json['exercise_id'] as int,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      restTime: json['rest_time'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'training_plan_id': trainingPlanId,
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'rest_time': restTime,
      'notes': notes,
    };
  }
}