import 'package:flutter/material.dart';
import 'package:personal_training/models/user_model.dart';
import 'package:personal_training/api_service.dart';
import 'package:personal_training/models/weight_history.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalsTab extends StatefulWidget {
  final User? user;
  final int? currentUserId; // Dodany parametr
  final Function(double) onWeightGoalChanged;
  final Function(User?)? onUserUpdated;

  const GoalsTab({
    super.key,
    required this.user,
    this.currentUserId, // Opcjonalny, ale preferowany
    required this.onWeightGoalChanged,
    this.onUserUpdated,
  });

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

extension IterableExtensions<T> on Iterable<T> {
  Iterable<E> mapIndexed<E>(E Function(int index, T item) f) {
    return toList().asMap().entries.map((entry) => f(entry.key, entry.value));
  }
}

class _GoalsTabState extends State<GoalsTab> {
  final TextEditingController weightGoalController = TextEditingController();
  final TextEditingController newWeightController = TextEditingController();
  List<WeightHistory> weightHistory = [];
  final ApiService apiService = ApiService();
  bool isLoading = false;
  User? currentUser; // Lokalna zmienna dla użytkownika

  @override
  void initState() {
    super.initState();
    _loadUserAndWeightHistory();
    if (widget.user?.weightGoal != null) {
      weightGoalController.text = widget.user!.weightGoal!.toString();
    }
  }

  Future<void> _loadUserAndWeightHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.currentUserId ?? prefs.getInt('currentUserId') ?? 1;

      // Pobierz użytkownika, jeśli nie został przekazany lub jest nieaktualny
      currentUser = widget.user ?? await apiService.fetchUser(userId);

      if (currentUser != null) {
        weightGoalController.text = currentUser!.weightGoal?.toString() ?? '';
        final history = await apiService.fetchWeightHistory(currentUser!.id);
        setState(() {
          weightHistory = history.toList()
            ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
        });
      } else {
        setState(() {
          weightHistory = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania danych: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatWeightDifference() {
    if (weightHistory.isEmpty || currentUser == null) {
      return 'Różnica o 0,0 kg';
    }

    final initialWeight = weightHistory.first.weight;
    final currentWeight = currentUser!.weight;
    final difference = initialWeight - currentWeight;

    if (difference < 0) {
      return 'Różnica o +${difference.abs().toStringAsFixed(1)} kg';
    } else if (difference > 0) {
      return 'Różnica o -${difference.toStringAsFixed(1)} kg';
    } else {
      return 'Różnica o 0,0 kg';
    }
  }

  @override
  void dispose() {
    weightGoalController.dispose();
    newWeightController.dispose();
    super.dispose();
  }

  void _updateWeightGoal() async {
    if (!mounted) return;
    final newGoal = double.tryParse(weightGoalController.text);
    if (newGoal != null && newGoal > 0 && currentUser != null) {
      widget.onWeightGoalChanged(newGoal);
      try {
        await apiService.updateUser(
          userId: currentUser!.id,
          weightGoal: newGoal,
        );
        currentUser = await apiService.fetchUser(currentUser!.id); // Aktualizacja użytkownika
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(currentUser);
        }
        await _loadUserAndWeightHistory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd zapisu celu wagi: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podaj poprawną wagę docelową')),
        );
      }
    }
  }

  Future<void> _addWeightMeasurement() async {
    if (!mounted || currentUser == null) return;
    final newWeight = double.tryParse(newWeightController.text);
    if (newWeight != null && newWeight > 0) {
      try {
        await apiService.createWeightHistory(
          userId: currentUser!.id,
          weight: newWeight,
        );
        await apiService.updateUser(
          userId: currentUser!.id,
          weight: newWeight,
        );
        currentUser = await apiService.fetchUser(currentUser!.id); // Aktualizacja użytkownika
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(currentUser);
        }
        await _loadUserAndWeightHistory();
        newWeightController.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd zapisu pomiaru: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podaj poprawną wagę')),
        );
      }
    }
  }

  void _showFullWeightHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Pełna historia wagi'),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: weightHistory.reversed.mapIndexed((index, data) {
                  final day = data.recordedAt.day.toString().padLeft(2, '0');
                  final month = data.recordedAt.month.toString().padLeft(2, '0');
                  final year = data.recordedAt.year;
                  final dateString = '$day.$month.$year';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateString,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          data.weight.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        _buildWeightChange(data.weight, index == 0),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
              child: const Text('Zamknij'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeightChange(double currentWeight, bool isLatest) {
    if (weightHistory.isEmpty) return const Text('0,0', style: TextStyle(fontSize: 14));
    final initialWeight = weightHistory.first.weight;
    final difference = initialWeight - currentWeight;
    final isNegative = difference > 0;
    final differenceString = difference.toStringAsFixed(1);
    return Text(
      differenceString,
      style: TextStyle(
        fontSize: 14,
        color: isNegative ? Colors.green : Colors.red,
        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  double _calculateAverageWeightChange() {
    if (weightHistory.length < 2) return 0.0;
    final sortedHistory = weightHistory.toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    double totalChange = 0.0;
    for (int i = 1; i < sortedHistory.length; i++) {
      totalChange += sortedHistory[i].weight - sortedHistory[i - 1].weight;
    }
    return totalChange / (sortedHistory.length - 1);
  }

  int _estimateDaysToGoal() {
    if (currentUser?.weightGoal == null || currentUser?.weight == null) return 0;
    final currentWeight = currentUser!.weight;
    final goalWeight = currentUser!.weightGoal!;
    final averageChange = _calculateAverageWeightChange();
    if (averageChange == 0) return 0;
    final weightDifference = goalWeight - currentWeight;
    final days = (weightDifference / averageChange).abs();
    return days.isFinite && days > 0 ? days.ceil() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final daysToGoal = _estimateDaysToGoal();
    final weightToGoal = currentUser?.weightGoal != null && currentUser?.weight != null
        ? (currentUser!.weight - currentUser!.weightGoal!).abs().toStringAsFixed(1)
        : '0.0';

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (states) {
                return Colors.transparent; // Ustawiamy tło na transparentne, aby gradient był widoczny
              },
            ),
            overlayColor: WidgetStateProperty.all(Colors.deepPurple.withOpacity(0.1)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple, // Ujednolicony kolor tekstu dla TextButton
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Do celu zostało: $weightToGoal kg!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aktualna waga: ${currentUser?.weight ?? 0.0} kg',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Waga (ostatnie 6 miesięcy)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: _buildWeightChart(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Wynik',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Cel',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(thickness: 2, color: Colors.grey),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.workspace_premium, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Waga docelowa (kg)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: weightGoalController,
                              decoration: const InputDecoration(
                                hintText: 'Wpisz wagę docelową',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _updateWeightGoal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Zapisz cel'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.fitness_center, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Nowy pomiar (kg)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: newWeightController,
                              decoration: const InputDecoration(
                                hintText: 'Wpisz nowy pomiar',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _addWeightMeasurement,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Dodaj pomiar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.grey[200],
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatWeightDifference(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Prognoza osiągnięcia celu*: za ${daysToGoal > 0 ? '$daysToGoal dni' : 'nie określono'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Historia wagi',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (weightHistory.length > 5)
                                ElevatedButton(
                                  onPressed: _showFullWeightHistory,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ).copyWith(
                                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                      (states) {
                                        if (states.contains(MaterialState.pressed)) {
                                          return Colors.deepPurple.shade600;
                                        }
                                        return Colors.transparent;
                                      },
                                    ),
                                    overlayColor: WidgetStateProperty.all(Colors.deepPurple.withOpacity(0.1)),
                                  ).copyWith(
                                    foregroundColor: WidgetStateProperty.all(Colors.white),
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.deepPurple.shade700,
                                          Colors.deepPurple.shade300,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      alignment: Alignment.center,
                                      child: const Text('Pokaż więcej'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(thickness: 1, color: Colors.grey),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('Pomiar (kg)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('Zmiana (kg)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: weightHistory.length > 5 ? weightHistory.length : 5,
                          itemBuilder: (context, index) {
                            if (index >= weightHistory.length) return const SizedBox.shrink();
                            final data = weightHistory.reversed.toList()[index];
                            final day = data.recordedAt.day.toString().padLeft(2, '0');
                            final month = data.recordedAt.month.toString().padLeft(2, '0');
                            final year = data.recordedAt.year;
                            final dateString = '$day.$month.$year';
                            final isLatest = index == 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateString,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    data.weight.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  _buildWeightChange(data.weight, isLatest),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWeightChart() {
    final List<FlSpot> weightSpots = weightHistory
        .map((data) => FlSpot(
              data.recordedAt.millisecondsSinceEpoch.toDouble(),
              data.weight,
            ))
        .toList()
        .where((spot) =>
            spot.x >=
            DateTime.now()
                .subtract(const Duration(days: 180))
                .millisecondsSinceEpoch
                .toDouble())
        .toList();

    List<FlSpot> goalSpots = [];
    if (currentUser?.weightGoal != null) {
      final lastDate = weightHistory.isNotEmpty
          ? weightHistory.last.recordedAt
          : DateTime.now();
      goalSpots = [
        FlSpot(lastDate.millisecondsSinceEpoch.toDouble(), currentUser!.weightGoal!)
      ];
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    if (currentUser?.weightGoal != null) {
      minY = currentUser!.weightGoal!;
      final allWeights = [
        ...weightSpots.map((spot) => spot.y),
        if (currentUser?.weight != null) currentUser!.weight,
      ];
      maxY = allWeights.isNotEmpty
          ? allWeights.reduce((a, b) => a > b ? a : b) + 5
          : currentUser!.weightGoal! + 20;
    } else {
      if (weightSpots.isNotEmpty || goalSpots.isNotEmpty) {
        final allWeights = [
          ...weightSpots.map((spot) => spot.y),
          if (currentUser?.weight != null) currentUser!.weight,
          if (currentUser?.weightGoal != null) currentUser!.weightGoal!,
        ];
        minY = allWeights.reduce((a, b) => a < b ? a : b) - 5;
        maxY = allWeights.reduce((a, b) => a > b ? a : b) + 5;
      } else {
        minY = 60;
        maxY = 100;
      }
    }

    final latestDate = weightHistory.isNotEmpty
        ? weightHistory.last.recordedAt
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch
            .toDouble()
        : DateTime.now().millisecondsSinceEpoch.toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          horizontalInterval: 5,
          verticalInterval: 30 * 24 * 60 * 60 * 1000,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 30 * 24 * 60 * 60 * 1000,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                final day = date.day.toString().padLeft(2, '0');
                final month = date.month.toString().padLeft(2, '0');
                return Text('$day.$month', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 12));
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        minX: weightHistory.isNotEmpty
            ? weightHistory.first.recordedAt.millisecondsSinceEpoch.toDouble()
            : DateTime.now().subtract(const Duration(days: 180)).millisecondsSinceEpoch.toDouble(),
        maxX: latestDate,
        minY: minY.isFinite ? minY : 60,
        maxY: maxY.isFinite ? maxY : 100,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (currentUser?.weightGoal != null)
              HorizontalLine(
                y: currentUser!.weightGoal!,
                color: Colors.red.withOpacity(0.5),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: weightSpots,
            isCurved: false,
            color: Colors.blue,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
            barWidth: 2,
          ),
          if (goalSpots.isNotEmpty)
            LineChartBarData(
              spots: goalSpots,
              isCurved: false,
              color: Colors.red,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
              barWidth: 2,
            ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.green.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                final day = date.day.toString().padLeft(2, '0');
                final month = date.month.toString().padLeft(2, '0');
                final year = date.year;
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} kg\n$day.$month.$year',
                  const TextStyle(color: Colors.black, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}