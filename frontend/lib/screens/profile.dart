import 'package:flutter/material.dart';
import 'package:personal_training/models/user_model.dart';
import 'package:personal_training/api_service.dart';
import 'package:personal_training/screens/goals_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final int? currentUserId;

  const ProfileScreen({super.key, this.currentUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  final ValueNotifier<User?> userNotifier = ValueNotifier(null);
  bool isLoading = true;
  bool isEditing = false;
  late TabController _tabController;

  late TextEditingController _nicknameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  String? _selectedGender;
  bool isChangingPlan = false;
  String? currentPlanVersion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _nicknameController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _loadUser();
  }

  void _onTabChanged() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final userId = widget.currentUserId ?? prefs.getInt('currentUserId');

      if (userId == null) {
        setState(() {
          userNotifier.value = null;
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak użytkownika. Utwórz konto.')),
        );
        return;
      }

      // Pobierz plan z SharedPreferences, żeby był aktualny
      final planFromPrefs = prefs.getString('planVersion');
      
      final user = await apiService.fetchUser(userId);
      setState(() {
        userNotifier.value = user;
        _nicknameController.text = user.nickname;
        _ageController.text = user.age.toString();
        _heightController.text = user.height.toString();
        _weightController.text = user.weight.toString();
        _selectedGender = user.gender;
        
        // Ustaw plan albo z API albo z SharedPreferences, dając priorytet SharedPreferences
        currentPlanVersion = planFromPrefs ?? user.planVersion;
        
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania danych: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (userNotifier.value == null) return;

    try {
      setState(() {
        isLoading = true;
      });
      final updatedUser = await apiService.updateUser(
        userId: userNotifier.value!.id,
        nickname: _nicknameController.text,
        age: int.tryParse(_ageController.text),
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        gender: _selectedGender,
      );
      setState(() {
        userNotifier.value = updatedUser;
        isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas zapisywania: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateWeightGoal(double newGoal) async {
    if (userNotifier.value == null) return;

    try {
      setState(() {
        isLoading = true;
      });
      final updatedUser = await apiService.updateUser(
        userId: userNotifier.value!.id,
        weightGoal: newGoal,
      );
      userNotifier.value = updatedUser;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd aktualizacji celu: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateUserFromGoalsTab(User? updatedUser) {
    if (updatedUser != null) {
      userNotifier.value = updatedUser;
      _nicknameController.text = updatedUser.nickname;
      _ageController.text = updatedUser.age.toString();
      _heightController.text = updatedUser.height.toString();
      _weightController.text = updatedUser.weight.toString();
      _selectedGender = updatedUser.gender;
    }
  }

  @override
  void dispose() {
    userNotifier.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _changePlan(String newPlanVersion) async {
    if (userNotifier.value == null) return;
    if (currentPlanVersion == newPlanVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Już używasz planu $newPlanVersion')),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      // Wywołanie API do zmiany planu
      await apiService.changePlan(
        userId: userNotifier.value!.id,
        planVersion: newPlanVersion,
      );

      // Aktualizacja użytkownika po zmianie planu
      final updatedUser = await apiService.fetchUser(userNotifier.value!.id);

      // Zapisz nowy plan_version w SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('planVersion', newPlanVersion);

      setState(() {
        userNotifier.value = updatedUser;
        currentPlanVersion = newPlanVersion; // Aktualizuj lokalną zmienną
        isChangingPlan = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Plan treningowy zmieniony na plan $newPlanVersion')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas zmiany planu: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.deepPurple,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Metoda która zwraca opis planu treningowego
  String _getPlanDescription(String? planVersion) {
    switch (planVersion) {
      case 'A':
        return 'Plan A (6/4/2)';
      case 'B':
        return 'Plan B (6/4/6)';
      default:
        return 'Nieznany plan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: Colors.deepPurple,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepPurple,
          accentColor: Colors.green,
          backgroundColor: Colors.grey[100],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.black54),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.black54),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.deepPurple, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.black54),
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: TextStyle(color: Colors.black87),
          prefixIconColor: Colors.black87,
          hintStyle: TextStyle(color: Colors.black),
          helperStyle: TextStyle(color: Colors.black),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Container(
                      color: Colors.grey[200],
                      child: TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: "Informacje"),
                          Tab(text: "Cele"),
                        ],
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black87,
                        indicator: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade700,
                              Colors.deepPurple.shade300,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<User?>(
                        valueListenable: userNotifier,
                        builder: (context, user, child) {
                          return TabBarView(
                            controller: _tabController,
                            children: [
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Podstawowe informacje',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.deepPurple,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  isEditing = !isEditing;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        if (!isEditing) ...[
                                          _buildInfoRow('Nick:',
                                              user?.nickname ?? 'Nie podano'),
                                          _buildInfoRow(
                                              'Wiek:',
                                              user?.age.toString() ??
                                                  'Nie podano'),
                                          _buildInfoRow('Wzrost:',
                                              '${user?.height.toStringAsFixed(1) ?? "Nie podano"} cm'),
                                          _buildInfoRow('Waga:',
                                              '${user?.weight.toStringAsFixed(1) ?? "Nie podano"} kg'),
                                          _buildInfoRow(
                                              'Płeć:',
                                              user?.gender == "M"
                                                  ? "Mężczyzna"
                                                  : user?.gender == "F"
                                                      ? "Kobieta"
                                                      : "Nie podano"),
                                          _buildInfoRow(
                                              'Plan treningowy:',
                                              _getPlanDescription(currentPlanVersion)),
                                          
                                          SizedBox(height: 15),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.swap_horiz),
                                            label: const Text('Zmień plan treningowy'),
                                            onPressed: () {
                                              setState(() {
                                                isChangingPlan = true;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          
                                          if (isChangingPlan)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 16.0),
                                              child: Card(
                                                elevation: 3,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                      color: Colors
                                                          .deepPurple.shade200,
                                                      width: 1),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      16.0),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Wybierz plan treningowy',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      const Text(
                                                        'Uwaga: Zmiana planu spowoduje wygenerowanie nowych treningów na wszystkie tygodnie i zresetowanie progresji.',
                                                        style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 12),
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceEvenly,
                                                        children: [
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                _changePlan(
                                                                    'A'),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor: currentPlanVersion == 'A'
                                                                  ? Colors.grey
                                                                  : Colors
                                                                      .deepPurple,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                            child: const Text(
                                                                'Plan A (6/4/2)'),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                _changePlan(
                                                                    'B'),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor: currentPlanVersion == 'B'
                                                                  ? Colors.grey
                                                                  : Colors
                                                                      .deepPurple,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                            child: const Text(
                                                                'Plan B (6/4/6)'),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: TextButton.icon(
                                                          icon: const Icon(
                                                              Icons.close),
                                                          label: const Text(
                                                              'Anuluj'),
                                                          onPressed: () {
                                                            setState(() {
                                                              isChangingPlan =
                                                                  false;
                                                            });
                                                          },
                                                          style: TextButton
                                                              .styleFrom(
                                                            foregroundColor:
                                                                Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ] else ...[
                                          TextField(
                                            controller: _nicknameController,
                                            decoration: const InputDecoration(
                                                labelText: 'Nick'),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _ageController,
                                            decoration: const InputDecoration(
                                                labelText: 'Wiek'),
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _heightController,
                                            decoration: const InputDecoration(
                                                labelText: 'Wzrost (cm)'),
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _weightController,
                                            decoration: const InputDecoration(
                                                labelText: 'Waga (kg)'),
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            value: _selectedGender,
                                            decoration: const InputDecoration(
                                                labelText: 'Płeć'),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'M',
                                                  child: Text('Mężczyzna')),
                                              DropdownMenuItem(
                                                  value: 'F',
                                                  child: Text('Kobieta')),
                                            ],
                                            onChanged: (value) => setState(
                                                () => _selectedGender = value),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton(
                                                onPressed: _saveChanges,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.deepPurple,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text(
                                                    'Aktualizuj dane'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              GoalsTab(
                                user: user,
                                onWeightGoalChanged: _updateWeightGoal,
                                onUserUpdated: _updateUserFromGoalsTab,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}