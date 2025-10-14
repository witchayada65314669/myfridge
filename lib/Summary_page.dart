import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'fridge_log_entry.dart'; // โมเดล typed ของ FridgeLog

// ===== Utils =====
class CardGradient {
  final Color c1, c2;
  const CardGradient(this.c1, this.c2);
}

class BarItem {
  final String name;
  final double kg;
  BarItem(this.name, this.kg);
}

// แสดงตัวเลขแบบ 1 ตำแหน่ง หากลงตัวให้ตัด .0 ออก
String formatKg(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? v.toStringAsFixed(0) : s;
}

class SummaryPage extends StatefulWidget {
  final String userId;
  const SummaryPage({super.key, required this.userId});
  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  // ====== Filters ======
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _allTime = true;

  // ย่อยของ Meat
  final List<String> meatTypes = const ['all', 'pork', 'beef', 'chicken'];
  String selectedMeat = 'all';

  // Firestore collection (typed)
  late final CollectionReference<FridgeLogEntry> _logCol = FirebaseFirestore
      .instance
      .collection('FridgeLog')
      .withConverter<FridgeLogEntry>(
        fromFirestore: FridgeLogEntry.fromFirestore,
        toFirestore: FridgeLogEntry.toFirestore,
      );

  // ====== Stream (Safe mode ตลอด: query แค่ userId แล้วกรองบนเครื่อง) ======
  Stream<List<FridgeLogEntry>> _itemsStream() {
    return _logCol
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .map((s) {
      final all = s.docs.map((d) => d.data()).toList()
        ..removeWhere((e) => e.eventType.name != 'added');

      if (_allTime) {
        all.sort((a, b) => b.eventAt.compareTo(a.eventAt));
        return all;
      }
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      final filtered = all
          .where((e) => !e.eventAt.isBefore(start) && e.eventAt.isBefore(end))
          .toList()
        ..sort((a, b) => b.eventAt.compareTo(a.eventAt));
      return filtered;
    });
  }

  // ===== Aggregations =====
  List<BarItem> _aggregateByName(List<FridgeLogEntry> raw) {
    final map = <String, double>{};
    for (final e in raw) {
      // ✅ normalize ชื่อ: ตัดช่องว่างหัวท้าย & ยุบช่องว่างซ้ำ
      final name = e.productName.trim().replaceAll(RegExp(r'\s+'), ' ');
      map[name] = (map[name] ?? 0) + e.quantityKg;
    }
    final list = map.entries.map((e) => BarItem(e.key, e.value)).toList();
    list.sort((a, b) => b.kg.compareTo(a.kg));
    return list;
  }

  double _sumKg(Iterable<FridgeLogEntry> it) =>
      it.fold<double>(0.0, (p, e) => p + e.quantityKg);

  Map<String, List<FridgeLogEntry>> _splitCategories(
      List<FridgeLogEntry> items) {
    final g = {
      'Meat': <FridgeLogEntry>[],
      'Vegetable': <FridgeLogEntry>[],
      'Fruit': <FridgeLogEntry>[],
      'Seafood': <FridgeLogEntry>[],
      'Other': <FridgeLogEntry>[],
    };
    for (final e in items) {
      switch (e.category) {
        case FoodCategory.pork:
        case FoodCategory.beef:
        case FoodCategory.chicken:
        case FoodCategory.meat:
          g['Meat']!.add(e);
          break;
        case FoodCategory.seafood:
          g['Seafood']!.add(e);
          break;
        case FoodCategory.vegetable:
          g['Vegetable']!.add(e);
          break;
        case FoodCategory.fruit:
          g['Fruit']!.add(e);
          break;
        default:
          g['Other']!.add(e);
      }
    }
    return g;
  }

  CardGradient _cardGradient(String cat) {
    switch (cat) {
      case 'Meat':
        return const CardGradient(Color(0xFF7B42C3), Color(0xFF6C35B7));
      case 'Vegetable':
        return const CardGradient(Color(0xFFC07BF4), Color(0xFF9B59D7));
      case 'Fruit':
        return const CardGradient(Color(0xFFE3D7FF), Color(0xFFD1B9FF));
      case 'Seafood':
        return const CardGradient(Color(0xFF8FA9FF), Color(0xFF6B85E6));
      case 'Other':
        return const CardGradient(Color(0xFF9E9E9E), Color(0xFF7E7E7E));
      default:
        return const CardGradient(Color(0xFF9E9E9E), Color(0xFF7E7E7E));
    }
  }

  // ===== Month controls =====
  void _prevMonth() => setState(() {
        _allTime = false;
        _selectedMonth =
            DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
      });

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() {
      _allTime = false;
      _selectedMonth = next;
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year, now.month, 31),
      helpText: 'เลือกเดือน',
    );
    if (picked != null) {
      setState(() {
        _allTime = false;
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<List<FridgeLogEntry>>(
          stream: _itemsStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'โหลดข้อมูลไม่สำเร็จ: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final loading = snap.connectionState == ConnectionState.waiting;
            final items = snap.data ?? const <FridgeLogEntry>[];
            final grouped = _splitCategories(items);

            // Meat + filter
            final meatAll = grouped['Meat']!;
            final meatFiltered = (selectedMeat == 'all')
                ? meatAll
                : meatAll
                    .where((e) => e.category.name == selectedMeat)
                    .toList();
            final double meatTotalShown = _sumKg(meatFiltered);

            // totals (Meat ใช้ยอดตามตัวกรอง)
            final totals = {
              'Meat': meatTotalShown,
              'Vegetable': _sumKg(grouped['Vegetable']!),
              'Fruit': _sumKg(grouped['Fruit']!),
              'Seafood': _sumKg(grouped['Seafood']!),
              'Other': _sumKg(grouped['Other']!),
            };
            final maxTotal = totals.values.isEmpty
                ? 1.0
                : totals.values
                    .reduce((a, b) => a > b ? a : b)
                    .clamp(1.0, double.infinity);

            Widget buildCard(String cat, List<FridgeLogEntry> raw,
                {Widget? trailing}) {
              final grad = _cardGradient(cat);
              final total = (cat == 'Meat') ? meatTotalShown : _sumKg(raw);
              final bars = _aggregateByName(cat == 'Meat' ? meatFiltered : raw);
              final progress = (total / maxTotal).clamp(0.0, 1.0);
              return _CategoryCard(
                title: cat,
                totalKg: total,
                bars: bars,
                color1: grad.c1,
                color2: grad.c2,
                trailing: trailing,
                progress: progress,
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context)),
                      const Text("summary",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Month filter + All
                  Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _allTime ? null : _prevMonth),
                      GestureDetector(
                        onTap: _pickMonth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1E9FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16, color: Colors.deepPurple.shade400),
                              const SizedBox(width: 8),
                              Text(_allTime ? 'All time' : monthLabel,
                                  style: TextStyle(
                                      color: Colors.deepPurple.shade600,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _allTime ? null : _nextMonth),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _allTime = !_allTime),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _allTime ? Colors.deepPurple : Colors.white,
                            border: Border.all(
                                color: Colors.deepPurple.shade300, width: 1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text('All',
                              style: TextStyle(
                                color:
                                    _allTime ? Colors.white : Colors.deepPurple,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (loading && items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // Cards
                  buildCard(
                    'Meat',
                    grouped['Meat']!,
                    trailing: _PillDropdown(
                      value: selectedMeat,
                      items: meatTypes,
                      onChanged: (v) =>
                          setState(() => selectedMeat = v ?? 'all'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildCard('Vegetable', grouped['Vegetable']!),
                  const SizedBox(height: 16),
                  buildCard('Fruit', grouped['Fruit']!),
                  const SizedBox(height: 16),
                  buildCard('Seafood', grouped['Seafood']!),
                  const SizedBox(height: 16),
                  buildCard('Other', grouped['Other']!),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PillDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: Color(0xFF6C35B7)),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(color: Color(0xFF6C35B7))),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final double totalKg;
  final List<BarItem> bars;
  final Color color1, color2;
  final Widget? trailing;
  final double progress;

  const _CategoryCard({
    required this.title,
    required this.totalKg,
    required this.bars,
    required this.color1,
    required this.color2,
    this.trailing,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = bars.isNotEmpty;
    final maxBar =
        hasData ? bars.map((b) => b.kg).reduce((a, b) => a > b ? a : b) : 5.0;
    final maxY = hasData ? maxBar * 1.5 : 5.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "total used ${formatKg(totalKg)} kg.",
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),

        // Chart
        SizedBox(
          height: 180,
          child: hasData
              ? LayoutBuilder(builder: (context, c) {
                  const double barWidth = 16;
                  const double gap = 20;
                  final contentWidth =
                      math.max(bars.length * (barWidth + gap) + 40, c.maxWidth);

                  final chart = SizedBox(
                    width: contentWidth,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(enabled: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          drawHorizontalLine: true,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.white.withOpacity(0.75),
                            strokeWidth: 1,
                            dashArray: const [6, 6],
                          ),
                        ),
                        extraLinesData: ExtraLinesData(horizontalLines: [
                          HorizontalLine(
                              y: 0,
                              color: Colors.white.withOpacity(0.9),
                              strokeWidth: 2),
                        ]),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              reservedSize: 24,
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                final i = value.toInt();
                                if (i >= 0 && i < bars.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      bars[i].name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(bars.length, (i) {
                          final isPrimary = i == 0;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: bars[i].kg,
                                width: barWidth,
                                gradient: LinearGradient(
                                  colors: isPrimary
                                      ? const [
                                          Color(0xFF3F5BD7),
                                          Color(0xFFBFD3FF)
                                        ]
                                      : const [Color(0xFFEFF2FF), Colors.white],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  );

                  // labels บนแท่ง
                  const double _labelLift = 0.22;
                  final int n = bars.length;
                  final labels = List.generate(n, (i) {
                    final y = bars[i].kg;
                    final yFrac = (y / maxY).clamp(0.0, 1.0);
                    final xFrac = (i + 1) / (n + 1);
                    final yAlign =
                        (1 - 2 * yFrac - _labelLift).clamp(-0.98, 0.98);
                    return Align(
                      alignment: Alignment(-1 + 2 * xFrac, yAlign),
                      child: Text(
                        "${formatKg(y)} kg.",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    );
                  });

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: contentWidth,
                        child: Stack(children: [chart, ...labels]),
                      ),
                    ),
                  );
                })
              : const Center(
                  child: Text("No data",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
        ),

        const SizedBox(height: 12),

        // Progress bar ด้านล่าง
        LayoutBuilder(builder: (context, c) {
          const trackH = 10.0;
          const thumbW = 56.0;
          final left = (c.maxWidth - thumbW) * progress;
          return SizedBox(
            height: 14,
            child: Stack(
              children: [
                Container(
                  height: trackH,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Positioned(
                  left: left,
                  top: 2,
                  child: Container(
                    width: thumbW,
                    height: trackH - 2.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ]),
    );
  }
}
