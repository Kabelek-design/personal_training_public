class WeightHistory {
  final int id;
  final int userId;
  final double weight;
  final DateTime recordedAt;

  WeightHistory({
    required this.id,
    required this.userId,
    required this.weight,
    required this.recordedAt,
  });

  factory WeightHistory.fromJson(Map<String, dynamic> json) {
    return WeightHistory(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      weight: (json['weight'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}