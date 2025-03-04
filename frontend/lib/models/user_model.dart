import 'package:personal_training/models/training_model.dart';
import 'package:personal_training/models/weight_history.dart';

class User {
  final int id;
  final String nickname;
  final int age;
  final double height;
  final double weight;
  final String gender;
  final double? weightGoal;
  final String? planVersion;
  final List<Exercise>? exercises; // Dodane, nullable
  final List<WeightHistory>? weightHistory; // Dodane, nullable

  User({
    required this.id,
    required this.nickname,
    required this.age,
    required this.height,
    required this.weight,
    required this.gender,
    this.weightGoal,
    this.planVersion,
    this.exercises,
    this.weightHistory,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nickname: json['nickname'] as String,
      age: json['age'] as int,
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      gender: json['gender'] as String,
      weightGoal: json['weight_goal'] != null ? (json['weight_goal'] as num).toDouble() : null,
      planVersion: json['plan_version'] != null ? json['plan_version'] as String : null,
      exercises: json['exercises'] != null ? (json['exercises'] as List).map((e) => Exercise.fromJson(e)).toList() : null,
      weightHistory: json['weight_history'] != null ? (json['weight_history'] as List).map((e) => WeightHistory.fromJson(e)).toList() : null,
    );
  }
}