import 'package:flutter/material.dart';
import 'package:personal_training/screens/training_schedule.dart';
import 'package:personal_training/screens/training_screen.dart';
import 'package:personal_training/screens/stats_screen.dart';
import 'package:personal_training/screens/profile.dart';
import 'package:personal_training/screens/onboarding_screen.dart';
import 'package:personal_training/screens/login_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Flaga do wymuszenia trybu pierwszego uruchomienia (dla testów)
// const bool FORCE_FIRST_LAUNCH = true; // Ta linijka jest zakomentowana, aby nie wymuszać ekranu startowego

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  final prefs = await SharedPreferences.getInstance();

  // Jeśli chcesz na stałe przestać wymuszać tryb pierwszego uruchomienia, usuń (lub zakomentuj) poniższy blok
  // if (FORCE_FIRST_LAUNCH) {
  //   await prefs.clear();
  //   print('Tryb testowy: Wyczyszczono SharedPreferences');
  // }
  
  final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
  final int? currentUserId = prefs.getInt('currentUserId');
  
  Widget initialScreen;
  // Usuwamy wymuszenie trybu pierwszego uruchomienia – logika opiera się tylko na wartości isFirstLaunch
  if (isFirstLaunch || currentUserId == null) {
    // Jeśli jest pierwsze uruchomienie lub nie ma zalogowanego użytkownika, pokaż ekran logowania/rejestracji
    initialScreen = const LoginSelectionScreen();
    print('Uruchamianie ekranu wyboru logowania/rejestracji (pierwsze uruchomienie lub brak zalogowanego użytkownika)');
  } else {
    // W przeciwnym razie pokaż ekran główny
    initialScreen = HomeScreen(currentUserId: currentUserId);
    print('Uruchamianie z istniejącym użytkownikiem: $currentUserId');
  }
  
  runApp(MyApp(initialScreen: initialScreen));
}

void showWorkoutReminder() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'workout_channel',
    'Workout Reminder',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails generalNotificationDetails =
      NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
      0, "Czas na trening!", "Dzisiaj masz siady!", generalNotificationDetails);
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trening & Dieta',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
        ),
      ),
      home: initialScreen,
    );
  }
}

// Nowy ekran wyboru między logowaniem a rejestracją
class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade400,
              Colors.deepPurple.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Progres Siłowy",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Twój osobisty trener siłowy",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "Zaloguj się",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const OnboardingScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Utwórz konto",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int? currentUserId;

  const HomeScreen({super.key, this.currentUserId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    if (_currentUserId == null) {
      _loadUserIdAndUpdatePages();
    } else {
      _initializePages();
    }
  }

  Future<void> _loadUserIdAndUpdatePages() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('currentUserId');
    if (_currentUserId == null) {
      print('Błąd: currentUserId nie znaleziono – przekierowanie na ekran logowania.');
      _navigateToLoginSelection();
      return;
    }
    _initializePages();
  }

  void _initializePages() {
    setState(() {
      _pages = [
        TrainingScreen(currentUserId: _currentUserId),
        TrainingScheduleScreen(currentUserId: _currentUserId!),
        StatsScreen(currentUserId: _currentUserId),
        ProfileScreen(currentUserId: _currentUserId),
      ];
    });
  }

  void _navigateToLoginSelection() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
    );
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      print(
          'Błąd: Nieprawidłowy indeks $index dla listy o długości ${_pages.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _pages.isNotEmpty
            ? _pages[_selectedIndex]
            : const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.fitness_center, "Ruchy siłowe", 0),
              _buildNavItem(Icons.calendar_today, "Plan", 1),
              _buildNavItem(Icons.bar_chart, "Wyniki", 2),
              _buildNavItem(Icons.person, "Profil", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 4,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: ColorTween(
            begin: isSelected ? Colors.white : Colors.deepPurple.shade300,
            end: isSelected ? Colors.deepPurple.shade300 : Colors.white,
          ),
          builder: (context, Color? backgroundColor, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          Colors.deepPurple.shade700,
                          Colors.deepPurple.shade300,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : backgroundColor,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 300),
                    tween: ColorTween(
                      begin: isSelected ? Colors.black : Colors.white,
                      end: isSelected ? Colors.white : Colors.black,
                    ),
                    builder: (context, Color? iconColor, _) {
                      return Icon(
                        icon,
                        color: iconColor,
                      );
                    },
                  ),
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 300),
                    tween: ColorTween(
                      begin: isSelected ? Colors.black : Colors.white,
                      end: isSelected ? Colors.white : Colors.black,
                    ),
                    builder: (context, Color? textColor, _) {
                      return Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: isSelected ? 14 : 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}