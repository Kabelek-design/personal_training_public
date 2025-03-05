import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:personal_training/models/training_model.dart';
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
          'Content-Type':
              'application/json; charset=utf-8', 
          'Accept':
              'application/json; charset=utf-8', 
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
        'Content-Type':
            'application/json; charset=utf-8', 
        'Accept':
            'application/json; charset=utf-8', 
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
        "Content-Type":
            "application/json; charset=utf-8", 
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
        'Content-Type':
            'application/json; charset=utf-8', 
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
}
