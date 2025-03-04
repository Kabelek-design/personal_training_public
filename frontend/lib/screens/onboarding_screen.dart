import 'package:flutter/material.dart';
import 'package:personal_training/main.dart';
import 'package:personal_training/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiService apiService = ApiService();
  bool isLoading = false;

  final nicknameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final weightGoalController = TextEditingController(); // Nowy kontroler dla weightGoal
  String? genderValue;
  String? selectedPlan;
  bool isPlanAExpanded = false;
  bool isPlanBExpanded = false;

  Future<void> _createUser() async {
    try {
      final nickname = nicknameController.text.trim();
      final age = int.tryParse(ageController.text) ?? 0;
      final height = double.tryParse(heightController.text) ?? 0.0;
      final weight = double.tryParse(weightController.text) ?? 0.0;
      final weightGoal = double.tryParse(weightGoalController.text) ?? 0.0;
      final gender = genderValue;
      final planVersion = selectedPlan;

      if (nickname.isEmpty ||
          age <= 0 ||
          height <= 0 ||
          weight <= 0 ||
          weightGoal <= 0 || // Sprawdzanie weightGoal
          gender == null ||
          planVersion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Wypełnij poprawnie wszystkie pola, w tym cel wagowy i wybór planu')),
        );
        return;
      }

      if (gender != "M" && gender != "F") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Płeć musi być "M" lub "F"')),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      // Wywołanie API do stworzenia użytkownika z wybranym planem i weightGoal
      final newUser = await apiService.createUser(
        nickname: nickname,
        age: age,
        height: height,
        weight: weight,
        gender: gender,
        planVersion: selectedPlan!, // Przekazanie wybranego planu
        weightGoal: weightGoal, // Przekazanie weightGoal
      );

      // Zapisujemy ID nowo utworzonego użytkownika, wybrany plan i flagę onboarding
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentUserId', newUser.id);
      await prefs.setString('planVersion', planVersion);
      await prefs.setBool('isFirstLaunch', false);

      // Przejście do HomeScreen z przekazaniem currentUserId
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(currentUserId: newUser.id),
        ),
      );
    } catch (e) {
      print('Błąd w _createUser: $e');
      if (e.toString().contains('400')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nick już zajęty lub nieprawidłowe dane')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    weightGoalController.dispose(); // Usunięcie nowego kontrolera
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
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
                "Progres Siłowy",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: Colors.deepPurple.shade600,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Zbuduj Siłę w Trzech Bojach',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade800,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black12,
                                    offset: const Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: Colors.deepPurple.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Podaj Swoje Dane',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade700,
                                        letterSpacing: 1.0,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black12,
                                            offset: const Offset(1, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextField(
                              controller: nicknameController,
                              decoration: const InputDecoration(
                                labelText: "Nick",
                                prefixIcon: Icon(Icons.person),
                                hintText: "Wybierz unikalny nick",
                              ),
                              style: const TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: ageController,
                              decoration: const InputDecoration(
                                labelText: "Wiek",
                                prefixIcon: Icon(Icons.cake),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: heightController,
                              decoration: const InputDecoration(
                                labelText: "Wzrost (cm)",
                                prefixIcon: Icon(Icons.height),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: weightController,
                              decoration: const InputDecoration(
                                labelText: "Waga (kg)",
                                prefixIcon: Icon(Icons.fitness_center),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: weightGoalController,
                              decoration: const InputDecoration(
                                labelText: "Cel Wagowy (kg)",
                                prefixIcon: Icon(Icons.scale),
                                hintText: "Podaj docelową wagę",
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: genderValue,
                              decoration: const InputDecoration(
                                labelText: "Płeć",
                                prefixIcon: Icon(Icons.people),
                                hintText: "Wybierz M lub F",
                              ),
                              items: const [
                                DropdownMenuItem(value: "M", child: Text("Mężczyzna")),
                                DropdownMenuItem(value: "F", child: Text("Kobieta")),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  genderValue = value;
                                });
                              },
                              style: const TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_run,
                            color: Colors.deepPurple.shade600,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Wybierz Swój Plan Siłowy',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black12,
                                    offset: const Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: selectedPlan == "A" ? Colors.deepPurple[100] : null,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedPlan = "A";
                                  isPlanAExpanded = !isPlanAExpanded;
                                  isPlanBExpanded = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Plan A',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: selectedPlan == "A"
                                                ? Colors.deepPurple
                                                : Colors.black87,
                                          ),
                                        ),
                                        Icon(
                                          isPlanAExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: selectedPlan == "A"
                                              ? Colors.deepPurple
                                              : Colors.black87,
                                        ),
                                      ],
                                    ),
                                    if (isPlanAExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10.0),
                                        child: Text(
                                          'Schemat 6-4-2, dla zaawansowanych. Skupia się na sile maksymalnej w przysiadach, martwym ciągu i wyciskaniu, z intensywnymi seriami 6, 4 i 2 powtórzeń, w tym AMRAP z 90% obciążenia dla maksymalnej siły.',
                                          style: TextStyle(fontSize: 14, color: Colors.black),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: selectedPlan == "B" ? Colors.deepPurple[100] : null,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedPlan = "B";
                                  isPlanBExpanded = !isPlanBExpanded;
                                  isPlanAExpanded = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Plan B',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: selectedPlan == "B"
                                                ? Colors.deepPurple
                                                : Colors.black87,
                                          ),
                                        ),
                                        Icon(
                                          isPlanBExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: selectedPlan == "B"
                                              ? Colors.deepPurple
                                              : Colors.black87,
                                        ),
                                      ],
                                    ),
                                    if (isPlanBExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10.0),
                                        child: Text(
                                          'Schemat 6-4-6, dla zaawansowanych. Obejmuje większy zakres powtórzeń z mniejszymi, ale odpowiednio ciężkimi obciążeniami w przysiadach, martwym ciągu i wyciskaniu, zapewniając progres siłowy i wytrzymałość.',
                                          style: TextStyle(fontSize: 14, color: Colors.black),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          onPressed: _createUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Rozpocznij",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}