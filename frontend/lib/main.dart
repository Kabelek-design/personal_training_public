import 'package:flutter/material.dart';
import 'screens/training_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile.dart';
import 'screens/onboarding_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/foundation.dart'; // Dodane dla kDebugMode

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(initSettings);

  // Usunięto resetowanie SharedPreferences – dane są teraz zachowywane
  final prefs = await SharedPreferences.getInstance();

  final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
  final int? currentUserId = prefs.getInt('currentUserId');
     // Usuń lub zakomentuj, jeśli nie jest potrzebne w testach
    // await prefs.clear();
  runApp(MyApp(isFirstLaunch: isFirstLaunch, initialUserId: currentUserId));
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
  final bool isFirstLaunch;
  final int? initialUserId;

  const MyApp({super.key, required this.isFirstLaunch, this.initialUserId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trening & Dieta',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: isFirstLaunch || initialUserId == null
          ? const OnboardingScreen()
          : HomeScreen(currentUserId: initialUserId),
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
  late List<Widget> _pages; // Używamy `late`, bo będzie zainicjalizowana w initState
  int? _currentUserId; // Przechowujemy aktualne ID użytkownika

  @override
  void initState() {
    super.initState();
    _currentUserId = (widget.currentUserId ?? _loadUserIdFromPrefs()) as int?;
    if (_currentUserId == null) {
      // Jeśli currentUserId nie istnieje, przekieruj na OnboardingScreen
      _navigateToOnboarding();
      return;
    }
    _loadUserIdAndUpdatePages(); // Inicjalizuj strony z poprawnym userId
  }

  // Metoda pomocnicza do pobierania currentUserId z SharedPreferences
  Future<int?> _loadUserIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('currentUserId');
  }

  Future<void> _loadUserIdAndUpdatePages() async {
    if (_currentUserId == null) {
      print('Błąd: currentUserId nie znaleziono w SharedPreferences – użytkownik musi się zarejestrować.');
      _navigateToOnboarding();
      return;
    }

    setState(() {
      _pages = [
        TrainingScreen(currentUserId: _currentUserId),
        StatsScreen(currentUserId: _currentUserId),
        ProfileScreen(currentUserId: _currentUserId),
      ];
    });
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      print('Błąd: Nieprawidłowy indeks $index dla listy o długości ${_pages.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _pages.isNotEmpty ? _pages[_selectedIndex] : const Center(child: CircularProgressIndicator()),
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
              _buildNavItem(Icons.fitness_center, "Trening", 0),
              _buildNavItem(Icons.bar_chart, "Statystyki", 1),
              _buildNavItem(Icons.person, "Profil", 2),
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
        width: MediaQuery.of(context).size.width / 3,
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