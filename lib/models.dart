/// 직업군. 고르는 직업군에 따라 입력할 수 있는 급여 방식이 달라진다.
enum JobType {
  fullTime('정규직', '💼', '매달 월급을 받는 직장인'),
  contract('계약직', '📋', '기간을 정해 일하는 직장인'),
  partTime('아르바이트', '🧋', '시급이나 일당을 받는 알바'),
  freelancer('프리랜서', '💻', '3.3%를 떼고 받는 외주·용역');

  const JobType(this.label, this.icon, this.description);
  final String label;
  final String icon;
  final String description;

  List<PayBasis> get payBases => switch (this) {
    JobType.fullTime ||
    JobType.contract => const [PayBasis.annualGross, PayBasis.monthlyNet],
    JobType.partTime => const [PayBasis.hourly, PayBasis.daily],
    JobType.freelancer => const [PayBasis.monthlyGross, PayBasis.daily],
  };

  /// 3.3% 원천징수를 기본으로 켤지.
  bool get defaultWithholding => this == JobType.freelancer;
}

/// 급여를 어떤 숫자로 입력하는지.
enum PayBasis {
  annualGross('세전 연봉', '연봉', '40,000,000'),
  monthlyNet('세후 월급', '월 실수령액', '3,500,000'),
  hourly('시급', '시급', '10,320'),
  daily('일당', '일당', '100,000'),
  monthlyGross('월 계약금', '월 계약금', '3,000,000');

  const PayBasis(this.label, this.amountLabel, this.hint);
  final String label;
  final String amountLabel;
  final String hint;

  /// 4대보험·소득세를 계산해서 뗀다.
  bool get usesPayrollTax => this == PayBasis.annualGross;

  /// 3.3% 원천징수를 고를 수 있다.
  bool get canWithhold =>
      this == PayBasis.hourly ||
      this == PayBasis.daily ||
      this == PayBasis.monthlyGross;

  /// 한 달 금액이 정해져 있고 그 달 근무일 수로 나눈다.
  bool get isMonthly =>
      this == PayBasis.annualGross ||
      this == PayBasis.monthlyNet ||
      this == PayBasis.monthlyGross;
}

/// 2026년 최저시급.
const minimumWage2026 = 10320;

/// 급여 계산에 쓰는 근무 설정. 시각은 자정 기준 분 단위.
class WorkSettings {
  const WorkSettings({
    this.jobType = JobType.fullTime,
    this.payBasis = PayBasis.monthlyNet,
    required this.payAmount,
    this.withholding = false,
    this.dependents = 1,
    this.nonTaxableMonthly = 0,
    required this.workWeekdays,
    required this.startMinute,
    required this.endMinute,
    required this.breakStartMinute,
    required this.breakEndMinute,
    this.paidBreak = true,
  });

  final JobType jobType;
  final PayBasis payBasis;

  /// [payBasis] 단위로 입력한 금액(원).
  final int payAmount;

  /// 3.3% 원천징수 적용 여부. [PayBasis.canWithhold] 일 때만 의미가 있다.
  final bool withholding;

  /// 공제대상가족 수(본인 포함). 세전 연봉일 때만 쓴다.
  final int dependents;

  /// 월 비과세액(식대 등). 세전 연봉일 때만 쓴다.
  final int nonTaxableMonthly;

  /// 근무 요일. DateTime.weekday 와 같은 1(월)~7(일).
  final Set<int> workWeekdays;
  final int startMinute;
  final int endMinute;

  /// 휴게시간. 시작과 끝이 같으면 휴게시간 없음.
  final int breakStartMinute;
  final int breakEndMinute;

  /// 휴게시간에도 급여가 쌓이는지(휴게시간을 급여에 포함하는지). 사용자가 켜고 끈다.
  /// - 켜짐: 출근부터 퇴근까지 쭉 쌓인다. 시급은 휴게시간도 근무 시간으로 친다.
  /// - 꺼짐: 휴게시간에는 멈춘다. 시급은 휴게시간을 빼고 계산한다.
  final bool paidBreak;

  bool get hasBreak => breakEndMinute > breakStartMinute;
  int get breakMinutes => hasBreak ? breakEndMinute - breakStartMinute : 0;

  /// 실제로 일하는 시간(휴게시간 제외).
  int get workMinutesPerDay => endMinute - startMinute - breakMinutes;

  /// 급여가 쌓이는 시간. 휴게시간을 급여에 포함하면 출근~퇴근 전체.
  int get paidMinutesPerDay =>
      paidBreak ? endMinute - startMinute : workMinutesPerDay;
  bool get appliesWithholding => withholding && payBasis.canWithhold;

  /// 세전 연봉으로 실수령액을 추정할 때 가정하는 월 비과세액(식대).
  /// 따로 묻지 않고, 추정이 틀리면 세후 월급을 직접 넣게 한다.
  static const defaultNonTaxableMonthly = 200000;

  /// 급여 입력이 잘못됐으면 고치는 방법을, 괜찮으면 null 을 돌려준다.
  static String? validatePay({
    required PayBasis payBasis,
    required int? payAmount,
  }) {
    if (payAmount == null) return '${payBasis.amountLabel}을 숫자로 입력해 주세요';
    if (payAmount <= 0) {
      return '${payBasis.amountLabel}은 0원보다 커야 해요. 다시 입력해 주세요.';
    }
    return null;
  }

  /// 근무 시간이 잘못됐으면 고치는 방법을, 괜찮으면 null 을 돌려준다.
  static String? validateTime({
    required Set<int> workWeekdays,
    required int startMinute,
    required int endMinute,
    required bool hasBreak,
    required int breakStartMinute,
    required int breakEndMinute,
  }) {
    if (workWeekdays.isEmpty) return '근무 요일을 하루 이상 골라 주세요';
    if (endMinute <= startMinute) {
      return '퇴근 시간이 출근 시간보다 늦어야 해요. 자정을 넘기는 근무는 아직 지원하지 않아요.';
    }
    if (hasBreak) {
      if (breakEndMinute <= breakStartMinute) {
        return '휴게 종료 시간이 휴게 시작 시간보다 늦어야 해요';
      }
      if (breakStartMinute < startMinute || breakEndMinute > endMinute) {
        return '휴게시간은 출근과 퇴근 사이로 맞춰 주세요';
      }
      if (endMinute - startMinute - (breakEndMinute - breakStartMinute) <= 0) {
        return '휴게시간을 빼면 근무 시간이 남지 않아요. 시간을 다시 확인해 주세요.';
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'jobType': jobType.name,
    'payBasis': payBasis.name,
    'payAmount': payAmount,
    'withholding': withholding,
    'dependents': dependents,
    'nonTaxableMonthly': nonTaxableMonthly,
    'workWeekdays': workWeekdays.toList()..sort(),
    'startMinute': startMinute,
    'endMinute': endMinute,
    'breakStartMinute': breakStartMinute,
    'breakEndMinute': breakEndMinute,
    'paidBreak': paidBreak,
  };

  factory WorkSettings.fromJson(Map<String, dynamic> j) {
    final weekdays = (j['workWeekdays'] as List).cast<int>().toSet();
    var jobType = JobType.fullTime;
    var basis = PayBasis.monthlyNet;
    var amount = j['payAmount'] as int;
    if (j['payBasis'] != null) {
      jobType = JobType.values.byName(j['jobType'] as String);
      basis = PayBasis.values.byName(j['payBasis'] as String);
    } else if (j['payCycle'] == 'weekly' && weekdays.isNotEmpty) {
      // 예전 형식(주급)은 하루치로 바꿔 계산 결과가 같게 둔다.
      jobType = JobType.partTime;
      basis = PayBasis.daily;
      amount = amount ~/ weekdays.length;
    }
    return WorkSettings(
      jobType: jobType,
      payBasis: basis,
      payAmount: amount,
      withholding: j['withholding'] as bool? ?? false,
      dependents: j['dependents'] as int? ?? 1,
      nonTaxableMonthly: j['nonTaxableMonthly'] as int? ?? 0,
      workWeekdays: weekdays,
      startMinute: j['startMinute'] as int,
      endMinute: j['endMinute'] as int,
      breakStartMinute: j['breakStartMinute'] as int,
      breakEndMinute: j['breakEndMinute'] as int,
      // 이 값이 없던 예전 설정도 켜짐(휴게시간에도 쌓임)으로 읽는다.
      paidBreak: j['paidBreak'] as bool? ?? true,
    );
  }
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
  }) => BenefitTemplate(
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
