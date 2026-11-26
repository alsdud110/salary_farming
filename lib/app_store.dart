import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'default_templates.dart';
import 'models.dart';
import 'salary_calculator.dart';

/// 한 기간의 합계.
class PeriodTotals {
  const PeriodTotals({required this.salary, required this.benefit});
  final int salary;
  final int benefit;
  int get total => salary + benefit;
  bool get isEmpty => salary == 0 && benefit == 0;
}

/// 혜택 종류별 집계 한 줄.
class BenefitSummary {
  BenefitSummary({required this.name, required this.icon});
  final String name;
  final String icon;
  int count = 0;
  int amount = 0;
}

/// 앱의 모든 상태. 서버 없이 기기 안(SharedPreferences)에만 저장한다.
class AppStore extends ChangeNotifier {
  AppStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _key = 'salary_farming_state_v1';

  final DateTime Function() _clock;
  SharedPreferences? _prefs;

  List<SettingsEntry> _history = [];
  List<BenefitTemplate> _templates = [];
  List<BenefitRecord> _records = [];
  int _seq = 0;

  DateTime now() => _clock();

  bool get isSetupDone => _history.isNotEmpty;
  WorkSettings? get currentSettings =>
      _history.isEmpty ? null : _history.last.settings;
  List<BenefitTemplate> get templates => List.unmodifiable(_templates);
  List<BenefitRecord> get records => List.unmodifiable(_records);

  /// 홈에 놓는 순서: 사용 빈도가 높은 것부터.
  List<BenefitTemplate> get templatesByFrequency {
    final list = [..._templates];
    mergeSort<BenefitTemplate>(
      list,
      compare: (a, b) => a.frequency.index.compareTo(b.frequency.index),
    );
    return list;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) {
      _templates = [...defaultTemplates];
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _history = (j['history'] as List)
          .map((e) => SettingsEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      _templates = (j['templates'] as List)
          .map((e) => BenefitTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      _records = (j['records'] as List)
          .map((e) => BenefitRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      _seq = j['seq'] as int? ?? 0;
    } catch (e) {
      // 읽을 수 없는 데이터면 덮어쓰지 않고 따로 남겨 둔 뒤 새로 시작한다.
      debugPrint('저장 데이터를 읽지 못했습니다: $e');
      await _prefs!.setString('${_key}_broken', raw);
      _history = [];
      _records = [];
      _templates = [...defaultTemplates];
    }
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs?.setString(
      _key,
      jsonEncode({
        'history': _history.map((e) => e.toJson()).toList(),
        'templates': _templates.map((e) => e.toJson()).toList(),
        'records': _records.map((e) => e.toJson()).toList(),
        'seq': _seq,
      }),
    );
  }

  String _newId(String prefix) =>
      '${prefix}_${now().microsecondsSinceEpoch}_${_seq++}';

  // ---- 설정 ----

  /// 설정 저장. 오늘부터 새 설정으로 계산하고 지난 날은 예전 설정대로 둔다.
  Future<void> saveSettings(WorkSettings settings) async {
    final today = dateOnly(now());
    _history.removeWhere((e) => !e.effectiveFrom.isBefore(today));
    _history.add(SettingsEntry(effectiveFrom: today, settings: settings));
    await _save();
  }

  /// [date] 에 적용되는 설정. 첫 설정 이전 날짜면 null.
  WorkSettings? settingsFor(DateTime date) {
    final day = dateOnly(date);
    WorkSettings? found;
    for (final e in _history) {
      if (e.effectiveFrom.isAfter(day)) break;
      found = e.settings;
    }
    return found;
  }

  // ---- 급여 ----

  double salaryOn(DateTime date, DateTime now) {
    final s = settingsFor(date);
    if (s == null) return 0;
    return SalaryCalculator.earnedOn(s, date, now);
  }

  double _salaryBetween(DateTime from, DateTime to, DateTime now) {
    var sum = 0.0;
    final today = dateOnly(now);
    final last = to.isAfter(today) ? today : dateOnly(to);
    for (var d = dateOnly(from);
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)) {
      sum += salaryOn(d, now);
    }
    return sum;
  }

  // ---- 혜택 기록 ----

  List<BenefitRecord> recordsBetween(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = DateTime(to.year, to.month, to.day + 1);
    return _records
        .where((r) => !r.at.isBefore(start) && r.at.isBefore(end))
        .toList();
  }

  List<BenefitRecord> recordsOn(DateTime date) {
    final list = recordsBetween(date, date);
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  int benefitBetween(DateTime from, DateTime to) =>
      recordsBetween(from, to).fold(0, (sum, r) => sum + r.amount);

  /// [from]~[to](둘 다 포함) 기간의 급여·혜택 합계.
  PeriodTotals totals(DateTime from, DateTime to, {DateTime? at}) {
    final n = at ?? now();
    return PeriodTotals(
      salary: _salaryBetween(from, to, n).floor(),
      benefit: benefitBetween(from, to),
    );
  }

  /// 혜택 종류별 횟수·금액. 금액이 큰 순.
  List<BenefitSummary> summarize(DateTime from, DateTime to) {
    final map = <String, BenefitSummary>{};
    for (final r in recordsBetween(from, to)) {
      final s = map.putIfAbsent(
        r.name,
        () => BenefitSummary(name: r.name, icon: r.icon),
      );
      s.count++;
      s.amount += r.amount;
    }
    return map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  Future<BenefitRecord> credit(BenefitTemplate t) async {
    final record = BenefitRecord(
      id: _newId('r'),
      templateId: t.id,
      name: t.name,
      icon: t.icon,
      amount: t.amount,
      at: now(),
    );
    _records.add(record);
    await _save();
    return record;
  }

  Future<void> removeRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _save();
  }

  // ---- 템플릿 ----

  Future<void> addTemplate({
    required String name,
    required String icon,
    required int amount,
    required UseFrequency frequency,
  }) async {
    _templates.add(BenefitTemplate(
      id: _newId('t'),
      name: name,
      icon: icon,
      amount: amount,
      category: BenefitCategory.custom,
      frequency: frequency,
    ));
    await _save();
  }

  Future<void> updateTemplate(BenefitTemplate t) async {
    final i = _templates.indexWhere((e) => e.id == t.id);
    if (i < 0) return;
    _templates[i] = t;
    await _save();
  }

  Future<void> removeTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    await _save();
  }

  // ---- 초기화 ----

  Future<void> resetAll() async {
    _history = [];
    _records = [];
    _templates = [...defaultTemplates];
    _seq = 0;
    notifyListeners();
    await _prefs?.remove(_key);
  }
}
