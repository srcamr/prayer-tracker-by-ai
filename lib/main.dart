import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const PrayerTrackerApp());
}

class PrayerTrackerApp extends StatelessWidget {
  const PrayerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متابعة الصلوات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9A84C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const MainPage(),
    );
  }
}

// ===================== MODELS =====================

const List<Map<String, String>> prayers = [
  {'id': 'fajr', 'name': 'الفجر', 'time': '4:30 ص'},
  {'id': 'dhuhr', 'name': 'الظهر', 'time': '12:15 م'},
  {'id': 'asr', 'name': 'العصر', 'time': '3:45 م'},
  {'id': 'maghrib', 'name': 'المغرب', 'time': '6:30 م'},
  {'id': 'isha', 'name': 'العشاء', 'time': '8:00 م'},
];

const List<Map<String, String>> checkpoints = [
  {'id': 'early', 'name': 'التبكير'},
  {'id': 'khushu1', 'name': 'الخشوع'},
  {'id': 'khushu2', 'name': 'الخشوع (إتمام)'},
  {'id': 'sunnah', 'name': 'السنن'},
];

const int pointsPerCheck = 100;
const int maxDayScore = 5 * 4 * 100; // 2000

String getTodayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

// ===================== MAIN PAGE =====================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  Map<String, Map<String, bool>> _allData = {};
  late SharedPreferences _prefs;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('prayerData');
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _allData = decoded.map((k, v) =>
          MapEntry(k, (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2 as bool))));
    }
    final today = getTodayKey();
    _allData.putIfAbsent(today, () => {});
    setState(() => _loaded = true);
  }

  Future<void> _saveData() async {
    final encoded = jsonEncode(_allData.map((k, v) => MapEntry(k, v)));
    await _prefs.setString('prayerData', encoded);
  }

  void _toggle(String prayerId, String cpId) {
    final today = getTodayKey();
    final key = '${prayerId}_$cpId';
    setState(() {
      _allData[today] ??= {};
      _allData[today]![key] = !(_allData[today]![key] ?? false);
    });
    _saveData();
  }

  int _getDayScore(String dayKey) {
    final d = _allData[dayKey] ?? {};
    return d.values.where((v) => v).length * pointsPerCheck;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C))),
      );
    }

    final today = getTodayKey();
    final todayScore = _getDayScore(today);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: Column(
            children: [
              const Text('🕌 متابعة الصلوات',
                  style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                DateFormat('EEEE d MMMM yyyy', 'ar').format(DateTime.now()),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '$todayScore',
                    style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: todayScore / maxDayScore,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFC9A84C)),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ $maxDayScore',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            TodayPage(
              allData: _allData,
              todayKey: today,
              onToggle: _toggle,
              getDayScore: _getDayScore,
            ),
            StatsPage(
              allData: _allData,
              getDayScore: _getDayScore,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF16213E),
          indicatorColor: const Color(0xFF0F3460),
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.home, color: Color(0xFFC9A84C)),
              label: 'اليوم',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFC9A84C)),
              label: 'المتابعة',
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== TODAY PAGE =====================

class TodayPage extends StatefulWidget {
  final Map<String, Map<String, bool>> allData;
  final String todayKey;
  final Function(String, String) onToggle;
  final int Function(String) getDayScore;

  const TodayPage({
    super.key,
    required this.allData,
    required this.todayKey,
    required this.onToggle,
    required this.getDayScore,
  });

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final checks = widget.allData[widget.todayKey] ?? {};
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prayers.length,
      itemBuilder: (ctx, i) {
        final prayer = prayers[i];
        final pId = prayer['id']!;
        int pScore = 0;
        for (final cp in checkpoints) {
          if (checks['${pId}_${cp['id']}'] == true) pScore += pointsPerCheck;
        }
        final maxP = checkpoints.length * pointsPerCheck;
        final isExpanded = _expanded.contains(pId);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: const Color(0xFFC9A84C).withOpacity(0.25)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  if (isExpanded) _expanded.remove(pId);
                  else _expanded.add(pId);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(prayer['name']!,
                                    style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 17, fontWeight: FontWeight.bold)),
                                Text(prayer['time']!,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('$pScore / $maxP',
                              style: const TextStyle(color: Colors.white60, fontSize: 13)),
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pScore / maxP,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFC9A84C)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: checkpoints.map((cp) {
                      final key = '${pId}_${cp['id']}';
                      final checked = checks[key] == true;
                      return GestureDetector(
                        onTap: () => widget.onToggle(pId, cp['id']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: checked
                                ? const Color(0xFF4CAF7D).withOpacity(0.15)
                                : const Color(0xFF0F3460),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: checked ? const Color(0xFF4CAF7D) : Colors.transparent,
                                  border: Border.all(
                                    color: checked ? const Color(0xFF4CAF7D) : Colors.white24,
                                    width: 2,
                                  ),
                                ),
                                child: checked
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  cp['name']!,
                                  style: TextStyle(
                                    color: checked ? const Color(0xFF81C9A0) : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '+$pointsPerCheck',
                                style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ===================== STATS PAGE =====================

class StatsPage extends StatefulWidget {
  final Map<String, Map<String, bool>> allData;
  final int Function(String) getDayScore;

  const StatsPage({super.key, required this.allData, required this.getDayScore});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _totalScore =>
      widget.allData.keys.fold(0, (s, k) => s + widget.getDayScore(k));

  int get _streak {
    final sorted = widget.allData.keys.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    for (final k in sorted) {
      if (widget.getDayScore(k) > 0) streak++;
      else break;
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final allDays = widget.allData.keys.toList()..sort();
    final totalDays = allDays.length;
    final maxAll = totalDays > 0 ? totalDays * maxDayScore : maxDayScore;
    final totalPct = (_totalScore / maxAll * 100).round();

    return Column(
      children: [
        // Summary
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Text(
                '$_totalScore',
                style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const Text('إجمالي النقاط', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 4),
              Text('النسبة: $totalPct%', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statBox('$totalDays', 'أيام مسجلة'),
                  _statBox('$_streak', 'أيام متتالية'),
                ],
              ),
            ],
          ),
        ),
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFC9A84C),
            labelColor: const Color(0xFFC9A84C),
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'الأسبوع'),
              Tab(text: 'الصلوات'),
              Tab(text: 'الأشهر'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWeekTab(),
              _buildPrayersTab(),
              _buildMonthsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String num, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(num, style: const TextStyle(color: Color(0xFFF0D88A), fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWeekTab() {
    final today = getTodayKey();
    final dayNames = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('آخر 14 يوم', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4,
            ),
            itemCount: 14,
            itemBuilder: (ctx, i) {
              final d = DateTime.now().subtract(Duration(days: 13 - i));
              final k = DateFormat('yyyy-MM-dd').format(d);
              final score = widget.getDayScore(k);
              final pct = score / maxDayScore;
              final isToday = k == today;
              Color bg;
              if (pct == 0) bg = Colors.white.withOpacity(0.05);
              else if (pct < 0.25) bg = const Color(0xFFC9A84C).withOpacity(0.2);
              else if (pct < 0.5) bg = const Color(0xFFC9A84C).withOpacity(0.4);
              else if (pct < 1.0) bg = const Color(0xFFC9A84C).withOpacity(0.65);
              else bg = const Color(0xFFC9A84C);
              final textColor = pct >= 1.0 ? const Color(0xFF1A1A2E) : Colors.white;
              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday ? Border.all(color: const Color(0xFFC9A84C), width: 1.5) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayNames[d.weekday % 7], style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 9)),
                    Text('${(pct * 100).round()}', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrayersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prayers.length,
      itemBuilder: (ctx, i) {
        final prayer = prayers[i];
        int total = 0, maxT = 0;
        widget.allData.forEach((dk, checks) {
          for (final cp in checkpoints) {
            maxT += pointsPerCheck;
            if (checks['${prayer['id']}_${cp['id']}'] == true) total += pointsPerCheck;
          }
        });
        final pct = maxT > 0 ? total / maxT : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(prayer['name']!, style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('$total / $maxT — ${(pct * 100).round()}%', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFC9A84C)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthsTab() {
    final monthMap = <String, Map<String, int>>{};
    final monthNames = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    widget.allData.forEach((dk, _) {
      final parts = dk.split('-');
      final mk = '${parts[0]}-${parts[1]}';
      monthMap.putIfAbsent(mk, () => {'score': 0, 'days': 0});
      monthMap[mk]!['score'] = monthMap[mk]!['score']! + widget.getDayScore(dk);
      monthMap[mk]!['days'] = monthMap[mk]!['days']! + 1;
    });
    final sorted = monthMap.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final mk = sorted[i];
        final parts = mk.split('-');
        final mName = monthNames[int.parse(parts[1])];
        final score = monthMap[mk]!['score']!;
        final days = monthMap[mk]!['days']!;
        final pct = days > 0 ? score / (days * maxDayScore) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(child: Text('$mName ${parts[0]}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFC9A84C)),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(pct * 100).round()}%', style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}
