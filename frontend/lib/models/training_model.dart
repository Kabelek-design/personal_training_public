class TrainingPlan {
  final int id;
  final int weekNumber;
  final int exerciseId;
  final List<TrainingSet> sets;

  TrainingPlan({
    required this.id,
    required this.weekNumber,
    required this.exerciseId,
    required this.sets,
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    return TrainingPlan(
      id: json['id'] as int,
      weekNumber: json['week_number'] as int,
      exerciseId: json['exercise_id'] as int,
      sets: (json['sets'] as List).map((e) => TrainingSet.fromJson(e)).toList(),
    );
  }
}

class Exercise {
  final int id;
  final String name;
  final double oneRepMax;
  final double progressWeight;
  final int? userId; // Dodane, nullable, jeśli nie zawsze zwracane

  Exercise({
    required this.id,
    required this.name,
    required this.oneRepMax,
    this.progressWeight = 0.0,
    this.userId, // Dodane
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      name: json['name'] as String,
      oneRepMax: (json['one_rep_max'] as num).toDouble(),
      progressWeight: (json['progress_weight'] as num?)?.toDouble() ?? 0.0,
      userId: json['user_id'] as int?, // Dodane
    );
  }
}

class TrainingSet {
  final int id;
  final int? weekPlanId; // Dodane, nullable, jeśli nie zawsze zwracane
  final int reps;
  final double percentage;
  final bool isAMRAP;
  final double weight;

  TrainingSet({
    required this.id,
    this.weekPlanId, // Dodane
    required this.reps,
    required this.percentage,
    this.isAMRAP = false,
    required this.weight,
  });

  factory TrainingSet.fromJson(Map<String, dynamic> json) {
    return TrainingSet(
      id: json['id'] as int,
      weekPlanId: json['week_plan_id'] as int?, // Dodane
      reps: json['reps'] as int,
      percentage: (json['percentage'] as num).toDouble(),
      isAMRAP: json['is_amrap'] as bool? ?? false,
      weight: (json['weight'] as num).toDouble(),
    );
  }
}
