import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:personal_training/models/training_model.dart';
import 'package:personal_training/models/training_schedule.dart';
import 'package:personal_training/models/user_model.dart';
import 'package:personal_training/models/weight_history.dart';
import 'constants.dart';

class ApiService {
  /// **Pobranie listy ćwiczeń**
  Future<List<Exercise>> fetchExercises({int? userId}) async {
    try {
      String endpoint = userId != null
          ? "users/$userId/$exercisesEndpoint"
          : exercisesEndpoint;
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => Exercise.fromJson(json)).toList();
      } else {
        throw Exception(
            'Błąd pobierania ćwiczeń: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// **Aktualizacja 1RM ćwiczenia i reset progresji**
  Future<void> updateExercise(
      int userId, int exerciseId, double newOneRepMax, String name) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/$userId/$exercisesEndpoint/$exerciseId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "one_rep_max": newOneRepMax,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Aktualizacja 1RM nie powiodła się: ${response.statusCode} - ${response.body}');
    }
  }

  /// **Pobranie planu treningowego na dany tydzień z wersją planu**
  Future<List<TrainingPlan>> fetchTrainingPlan(
      int userId, int weekNumber, String planVersion) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/users/$userId/plan/week/$weekNumber?plan_version=$planVersion'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => TrainingPlan.fromJson(json)).toList();
    } else {
      throw Exception(
          'Nie udało się pobrać planu treningowego: ${response.statusCode}');
    }
  }

  /// **Zapisanie wyniku AMRAP i aktualizacja progresji**
  Future<void> updateAmrapWeights({
    required int userId,
    required int setId,
    required int actualReps,
    required int weekNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/plan/week/$weekNumber/amrap'),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
      },
      body: jsonEncode({
        "set_id": setId,
        "reps_performed": actualReps,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Aktualizacja AMRAP nie powiodła się: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> addExercise(int userId, String name, double oneRepMax) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/$exercisesEndpoint'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: json.encode([
        {'name': name, 'one_rep_max': oneRepMax}
      ]),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Nie udało się dodać ćwiczenia: ${response.statusCode} - ${response.body}');
    }
  }

  /// **Usunięcie ćwiczenia**
  Future<void> deleteExercise(int userId, int exerciseId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId/$exercisesEndpoint/$exerciseId'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Nie udało się usunąć ćwiczenia: ${response.statusCode} - ${response.body}');
    }
  }

  /// **Pobranie listy użytkowników**
  Future<List<User>> fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$usersEndpoint'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception(
            'Błąd pobierania użytkowników: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// **Pobranie danych konkretnego użytkownika**
  Future<User> fetchUser(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$usersEndpoint${userId.toString()}'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return User.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Użytkownik nie znaleziony');
      } else {
        throw Exception(
            'Błąd pobierania użytkownika: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  Future<User> createUser({
    required String nickname,
    required int age,
    required double height,
    required double weight,
    required String gender,
    required double weightGoal,
    required String planVersion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$usersEndpoint?plan_version=$planVersion'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'nickname': nickname,
        'age': age,
        'height': height,
        'weight': weight,
        'gender': gender,
        'plan_version': planVersion,
        'weight_goal': weightGoal,
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception(
          'Nie udało się utworzyć użytkownika: ${response.statusCode}');
    }
  }

  Future<User> updateUser({
    required int userId,
    String? nickname,
    int? age,
    double? height,
    double? weight,
    String? gender,
    double? weightGoal,
    String? planVersion,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$usersEndpoint${userId.toString()}'),
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({
          if (nickname != null) "nickname": nickname,
          if (age != null) "age": age,
          if (height != null) "height": height,
          if (weight != null) "weight": weight,
          if (gender != null) "gender": gender,
          if (weightGoal != null) "weight_goal": weightGoal,
          if (planVersion != null) "plan_version": planVersion,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return User.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Użytkownik nie znaleziony');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(utf8.decode(response.bodyBytes))['detail'];
        throw Exception('Błąd aktualizacji użytkownika: $error');
      } else {
        throw Exception(
            'Aktualizacja użytkownika nie powiodła się: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// **Usunięcie użytkownika**
  Future<void> deleteUser(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$usersEndpoint/${userId.toString()}'),
        headers: {"Content-Type": "application/json; charset=utf-8"},
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Użytkownik nie znaleziony');
      } else {
        throw Exception(
            'Usuwanie użytkownika nie powiodło się: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  Future<List<WeightHistory>> fetchWeightHistory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$usersEndpoint${userId.toString()}/weight_history'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => WeightHistory.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw Exception(
            'Historia wagi dla użytkownika $userId nie znaleziona: ${response.body}');
      } else {
        throw Exception(
            'Błąd pobierania historii wagi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is http.ClientException || e is FormatException) {
        throw Exception('Błąd sieciowy lub niepoprawny format danych: $e');
      }
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  Future<void> createWeightHistory({
    required int userId,
    required double weight,
  }) async {
    final uri =
        Uri.parse('$baseUrl/$usersEndpoint${userId.toString()}/weight_history')
            .replace(queryParameters: {'weight': weight.toString()});

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'accept': 'application/json; charset=utf-8',
      },
      body: null,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Błąd zapisu pomiaru: ${response.statusCode} - ${response.body}');
    }
  }

// Plan treningowy hyper
  Future<List<TrainingPlanSchedule>> getAllTrainingPlans(
    int userId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/users/$userId/training-schedule/');
      if (fromDate != null || toDate != null) {
        final queryParams = <String, String>{};
        if (fromDate != null) {
          queryParams['from_date'] =
              fromDate.toIso8601String().substring(0, 10);
        }
        if (toDate != null) {
          queryParams['to_date'] = toDate.toIso8601String().substring(0, 10);
        }
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => TrainingPlanSchedule.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw Exception(
            'Nie znaleziono planów treningowych dla użytkownika $userId');
      } else {
        throw Exception(
            'Błąd pobierania planów treningowych: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Pobieranie harmonogramu na konkretny dzień
  Future<List<TrainingPlanSchedule>> getTrainingPlansForDay(
      int userId, DateTime dayDate) async {
    try {
      final formattedDate = dayDate.toIso8601String().substring(0, 10);
      final response = await http.get(
        Uri.parse(
            '$baseUrl/users/$userId/training-schedule/day/$formattedDate'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => TrainingPlanSchedule.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw Exception('Nie znaleziono planów na dzień $formattedDate');
      } else {
        throw Exception(
            'Błąd pobierania planów na dzień: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Pobieranie harmonogramu na bieżący tydzień
  Future<List<TrainingPlanSchedule>> getTrainingPlansForCurrentWeek(
      int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/training-schedule/current-week'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => TrainingPlanSchedule.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw Exception('Nie znaleziono planów na bieżący tydzień');
      } else {
        throw Exception(
            'Błąd pobierania planów na tydzień: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Pobieranie konkretnego planu treningowego
  Future<TrainingPlanSchedule> getTrainingPlan(
      int userId, int trainingPlanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/training-schedule/$trainingPlanId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return TrainingPlanSchedule.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Plan treningowy $trainingPlanId nie znaleziony');
      } else {
        throw Exception(
            'Błąd pobierania planu: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Tworzenie nowego planu treningowego
  Future<TrainingPlanSchedule> createTrainingPlan(
      int userId, TrainingPlanSchedule plan) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/training-schedule/'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode(plan.toJson()
          ..remove('id')
          ..remove('created_at')), // ID i created_at nadaje backend
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return TrainingPlanSchedule.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Użytkownik $userId nie znaleziony');
      } else if (response.statusCode == 400) {
        throw Exception('Błąd danych: ${response.body}');
      } else {
        throw Exception('Nie udało się utworzyć planu: - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Aktualizacja planu treningowego
  Future<TrainingPlanSchedule> updateTrainingPlan(
      int userId, int trainingPlanId, Map<String, dynamic> updateData) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/training-schedule/$trainingPlanId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return TrainingPlanSchedule.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Plan treningowy $trainingPlanId nie znaleziony');
      } else {
        throw Exception(
            'Aktualizacja planu nie powiodła się: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Usuwanie planu treningowego
  Future<void> deleteTrainingPlan(int userId, int trainingPlanId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId/training-schedule/$trainingPlanId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Plan treningowy $trainingPlanId nie znaleziony');
      } else {
        throw Exception(
            'Usunięcie planu nie powiodło się: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Dodawanie ćwiczenia do planu
  Future<ExerciseSchedule> addExerciseToPlan(
      int userId, int trainingPlanId, ExerciseSchedule exercise) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl/users/$userId/training-schedule/$trainingPlanId/exercises'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode(exercise.toJson()..remove('id')), // ID nadaje backend
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ExerciseSchedule.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Plan $trainingPlanId lub ćwiczenie nie znalezione');
      } else {
        throw Exception(
            'Nie udało się dodać ćwiczenia: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Aktualizacja ćwiczenia w planie
  Future<ExerciseSchedule> updateExerciseInPlan(int userId, int trainingPlanId,
      int exerciseScheduleId, Map<String, dynamic> updateData) async {
    try {
      final response = await http.patch(
        Uri.parse(
            '$baseUrl/users/$userId/training-schedule/$trainingPlanId/exercises/$exerciseScheduleId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ExerciseSchedule.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Ćwiczenie $exerciseScheduleId nie znalezione');
      } else {
        throw Exception(
            'Aktualizacja ćwiczenia nie powiodła się: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  /// Usuwanie ćwiczenia z planu
  Future<void> deleteExerciseFromPlan(
      int userId, int trainingPlanId, int exerciseScheduleId) async {
    try {
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/users/$userId/training-schedule/$trainingPlanId/exercises/$exerciseScheduleId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Ćwiczenie $exerciseScheduleId nie znalezione');
      } else {
        throw Exception(
            'Usunięcie ćwiczenia nie powiodło się: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Wystąpił wyjątek: $e');
    }
  }

  Future<Map<String, dynamic>> changePlan({
    required int userId,
    required String planVersion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$usersEndpoint${userId.toString()}/change-plan'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "plan_version": planVersion,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          'Nie udało się zmienić planu treningowego: ${response.statusCode} - ${response.body}');
    }
  }

Future<Map<String, dynamic>> comparePlans({required int userId}) async {
  final response = await http.get(
    Uri.parse('$baseUrl/$usersEndpoint$userId/$comparePlansEndpoint'),
    headers: {"Content-Type": "application/json"},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception(
        'Nie udało się pobrać porównania planów: ${response.statusCode} - ${response.body}');
  }
}
}
