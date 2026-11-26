/// 급여 지급 주기.
enum PayCycle {
  monthly('월급', '한 달'),
  weekly('주급', '한 주');

  const PayCycle(this.label, this.periodLabel);
  final String label;
  final String periodLabel;
}

/// 급여 계산에 쓰는 근무 설정. 시각은 자정 기준 분 단위.
class WorkSettings {
  const WorkSettings({
    required this.payAmount,
    required this.payCycle,
    required this.workWeekdays,
    required this.startMinute,
    required this.endMinute,
    required this.breakStartMinute,
    required this.breakEndMinute,
  });

  /// 지급 주기 한 번에 받는 금액(원).
  final int payAmount;
  final PayCycle payCycle;

  /// 근무 요일. DateTime.weekday 와 같은 1(월)~7(일).
  final Set<int> workWeekdays;
  final int startMinute;
  final int endMinute;

  /// 휴게시간. 시작과 끝이 같으면 휴게시간 없음.
  final int breakStartMinute;
  final int breakEndMinute;

  bool get hasBreak => breakEndMinute > breakStartMinute;
  int get breakMinutes => hasBreak ? breakEndMinute - breakStartMinute : 0;
  int get workMinutesPerDay => endMinute - startMinute - breakMinutes;

  /// 저장할 수 없는 설정이면 고치는 방법을 담은 문구를, 괜찮으면 null 을 돌려준다.
  static String? validate({
    required int? payAmount,
    required Set<int> workWeekdays,
    required int startMinute,
    required int endMinute,
    required bool hasBreak,
    required int breakStartMinute,
    required int breakEndMinute,
  }) {
    if (payAmount == null) return '급여 금액을 숫자로 입력해 주세요.';
    if (payAmount <= 0) return '급여는 0원보다 커야 해요. 금액을 다시 입력해 주세요.';
    if (workWeekdays.isEmpty) return '근무 요일을 하루 이상 골라 주세요.';
    if (endMinute <= startMinute) {
      return '퇴근 시간이 출근 시간보다 늦어야 해요. 자정을 넘기는 근무는 아직 지원하지 않아요.';
    }
    if (hasBreak) {
      if (breakEndMinute <= breakStartMinute) {
        return '휴게 종료 시간이 휴게 시작 시간보다 늦어야 해요.';
      }
      if (breakStartMinute < startMinute || breakEndMinute > endMinute) {
        return '휴게시간은 출근과 퇴근 사이로 맞춰 주세요.';
      }
      if (endMinute - startMinute - (breakEndMinute - breakStartMinute) <= 0) {
        return '휴게시간을 빼면 근무 시간이 남지 않아요. 시간을 다시 확인해 주세요.';
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'payAmount': payAmount,
        'payCycle': payCycle.name,
        'workWeekdays': workWeekdays.toList()..sort(),
        'startMinute': startMinute,
        'endMinute': endMinute,
        'breakStartMinute': breakStartMinute,
        'breakEndMinute': breakEndMinute,
      };

  factory WorkSettings.fromJson(Map<String, dynamic> j) => WorkSettings(
        payAmount: j['payAmount'] as int,
        payCycle: PayCycle.values.byName(j['payCycle'] as String),
        workWeekdays: (j['workWeekdays'] as List).cast<int>().toSet(),
        startMinute: j['startMinute'] as int,
        endMinute: j['endMinute'] as int,
        breakStartMinute: j['breakStartMinute'] as int,
        breakEndMinute: j['breakEndMinute'] as int,
      );
}

/// 설정 변경 이력. [effectiveFrom] 날짜부터 이 설정으로 급여를 계산한다.
/// 설정을 바꿔도 지난 날의 급여가 바뀌지 않게 하려고 이력으로 둔다.
class SettingsEntry {
  const SettingsEntry({required this.effectiveFrom, required this.settings});
  final DateTime effectiveFrom;
  final WorkSettings settings;

  Map<String, dynamic> toJson() => {
        'effectiveFrom': effectiveFrom.toIso8601String(),
        'settings': settings.toJson(),
      };

  factory SettingsEntry.fromJson(Map<String, dynamic> j) => SettingsEntry(
        effectiveFrom: DateTime.parse(j['effectiveFrom'] as String),
        settings: WorkSettings.fromJson(j['settings'] as Map<String, dynamic>),
      );
}

enum BenefitCategory {
  food('음식·음료'),
  facility('회사 시설'),
  custom('내 혜택');

  const BenefitCategory(this.label);
  final String label;
}

/// 사용 빈도. 자주 쓰는 템플릿일수록 홈에서 앞쪽에 놓인다.
enum UseFrequency {
  daily('매일'),
  often('자주'),
  sometimes('가끔');

  const UseFrequency(this.label);
  final String label;
}

class BenefitTemplate {
  const BenefitTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.amount,
    required this.category,
    required this.frequency,
    this.isDefault = false,
  });

  final String id;
  final String name;

  /// 이모지 한 글자.
  final String icon;
  final int amount;
  final BenefitCategory category;
  final UseFrequency frequency;
  final bool isDefault;

  BenefitTemplate copyWith({
    String? name,
    String? icon,
    int? amount,
    UseFrequency? frequency,
  }) =>
      BenefitTemplate(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        amount: amount ?? this.amount,
        category: category,
        frequency: frequency ?? this.frequency,
        isDefault: isDefault,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'amount': amount,
        'category': category.name,
        'frequency': frequency.name,
        'isDefault': isDefault,
      };

  factory BenefitTemplate.fromJson(Map<String, dynamic> j) => BenefitTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String,
        amount: j['amount'] as int,
        category: BenefitCategory.values.byName(j['category'] as String),
        frequency: UseFrequency.values.byName(j['frequency'] as String),
        isDefault: j['isDefault'] as bool? ?? false,
      );
}

/// 적립 한 건. 템플릿이 나중에 바뀌거나 지워져도 기록은 그대로 남도록
/// 이름·아이콘·금액을 적립 시점 값으로 따로 가진다.
class BenefitRecord {
  const BenefitRecord({
    required this.id,
    required this.templateId,
    required this.name,
    required this.icon,
    required this.amount,
    required this.at,
  });

  final String id;
  final String templateId;
  final String name;
  final String icon;
  final int amount;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'name': name,
        'icon': icon,
        'amount': amount,
        'at': at.toIso8601String(),
      };

  factory BenefitRecord.fromJson(Map<String, dynamic> j) => BenefitRecord(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String,
        amount: j['amount'] as int,
        at: DateTime.parse(j['at'] as String),
      );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
