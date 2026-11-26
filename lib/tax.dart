/// 한 달 급여에서 빠지는 금액(원). 2026년 기준 추정치.
class PayrollDeduction {
  const PayrollDeduction({
    required this.gross,
    required this.pension,
    required this.health,
    required this.longTermCare,
    required this.employment,
    required this.incomeTax,
    required this.localTax,
  });

  /// 비과세를 포함한 월 세전 급여.
  final int gross;
  final int pension;
  final int health;
  final int longTermCare;
  final int employment;
  final int incomeTax;
  final int localTax;

  int get insurance => pension + health + longTermCare + employment;
  int get tax => incomeTax + localTax;
  int get total => insurance + tax;
  int get net => gross - total;
}

/// 세전 연봉 → 월 실수령액 추정.
///
/// 근거(2026년):
/// - 국민연금 근로자 4.75%(총 9.5%), 기준소득월액 41만~659만원(2026.7~2027.6)
/// - 건강보험 근로자 3.595%(총 7.19%), 장기요양 = 건강보험료의 13.14%
/// - 고용보험 근로자 0.9%
/// - 소득세: 소득세법 시행령 별표2 근로소득 간이세액표의 산출 방식
///   (근로소득공제·인적공제·연금보험료공제·특별소득공제 산식·기본세율·근로소득세액공제)
///   을 그대로 계산한다. 자녀세액공제는 반영하지 않는다.
/// - 지방소득세 = 소득세의 10%
///
/// 실제 명세서와는 회사의 비과세 항목, 상여 지급 방식 등에 따라 조금 다를 수 있다.
class TaxCalculator {
  const TaxCalculator._();

  static const pensionRate = 0.0475;
  static const pensionBaseMin = 410000;
  static const pensionBaseMax = 6590000;
  static const healthRate = 0.03595;
  static const longTermCareRatio = 0.1314;
  static const employmentRate = 0.009;

  /// 프리랜서·알바 3.3% 원천징수(소득세 3% + 지방소득세 0.3%).
  static const withholdingRate = 0.033;

  static int _floor10(num v) => (v ~/ 10) * 10;

  /// [annualGross] 세전 연봉, [nonTaxableMonthly] 월 비과세액(식대 등),
  /// [dependents] 공제대상가족 수(본인 포함).
  static PayrollDeduction fromAnnual({
    required int annualGross,
    int nonTaxableMonthly = 0,
    int dependents = 1,
  }) {
    final gross = annualGross ~/ 12;
    final taxable = (gross - nonTaxableMonthly).clamp(0, gross);

    final pensionBase =
        (taxable.clamp(pensionBaseMin, pensionBaseMax) ~/ 1000) * 1000;
    final pension = taxable == 0 ? 0 : _floor10(pensionBase * pensionRate);
    final health = _floor10(taxable * healthRate);
    final longTermCare = _floor10(health * longTermCareRatio);
    final employment = _floor10(taxable * employmentRate);

    // 간이세액표는 월급여 106만원 미만 구간의 세액이 0원이다.
    final incomeTax = taxable < 1060000
        ? 0
        : _floor10(
            annualIncomeTax(
                  annualTaxable: taxable * 12,
                  annualPension: pension * 12,
                  dependents: dependents,
                ) /
                12,
          );
    final localTax = _floor10(incomeTax * 0.1);

    return PayrollDeduction(
      gross: gross,
      pension: pension,
      health: health,
      longTermCare: longTermCare,
      employment: employment,
      incomeTax: incomeTax,
      localTax: localTax,
    );
  }

  /// 간이세액표 산출 방식에 따른 연간 결정세액.
  static double annualIncomeTax({
    required int annualTaxable,
    required int annualPension,
    required int dependents,
  }) {
    final a = annualTaxable.toDouble();
    if (a <= 0) return 0;
    final family = dependents.clamp(1, 11);

    final earnedIncome = a - earnedIncomeDeduction(a);
    final taxBase =
        earnedIncome -
        1500000.0 * family -
        annualPension -
        specialDeduction(a, family);
    if (taxBase <= 0) return 0;

    final computed = basicTax(taxBase);
    final credit = earnedIncomeCredit(computed, a);
    final result = computed - credit;
    return result < 0 ? 0 : result;
  }

  /// 근로소득공제(한도 2천만원).
  static double earnedIncomeDeduction(double a) {
    final double d;
    if (a <= 5000000) {
      d = a * 0.7;
    } else if (a <= 15000000) {
      d = 3500000 + (a - 5000000) * 0.4;
    } else if (a <= 45000000) {
      d = 7500000 + (a - 15000000) * 0.15;
    } else if (a <= 100000000) {
      d = 12000000 + (a - 45000000) * 0.05;
    } else {
      d = 14750000 + (a - 100000000) * 0.02;
    }
    return d > 20000000 ? 20000000 : d;
  }

  /// 간이세액표의 특별소득공제·특별세액공제 반영 산식.
  static double specialDeduction(double a, int family) {
    if (family >= 3) {
      final extra = a > 40000000 ? (a - 40000000) * 0.04 : 0.0;
      if (a <= 30000000) return 5000000 + a * 0.07 + extra;
      if (a <= 45000000) {
        return 5000000 + a * 0.07 - (a - 30000000) * 0.05 + extra;
      }
      if (a <= 70000000) return 5000000 + a * 0.05 + extra;
      return 5000000 + a * 0.03 + extra;
    }
    final base = family == 2 ? 3600000.0 : 3100000.0;
    if (a <= 30000000) return base + a * 0.04;
    if (a <= 45000000) return base + a * 0.04 - (a - 30000000) * 0.05;
    if (a <= 70000000) return base + a * (family == 2 ? 0.02 : 0.015);
    return base + a * (family == 2 ? 0.01 : 0.005);
  }

  /// 종합소득세 기본세율(2023년 이후).
  static double basicTax(double base) {
    const brackets = <(double, double, double)>[
      // (구간 상한, 누진 기본세액, 세율)
      (14000000, 0, 0.06),
      (50000000, 840000, 0.15),
      (88000000, 6240000, 0.24),
      (150000000, 15360000, 0.35),
      (300000000, 37060000, 0.38),
      (500000000, 94060000, 0.40),
      (1000000000, 174060000, 0.42),
      (double.infinity, 384060000, 0.45),
    ];
    var lower = 0.0;
    for (final (upper, fixed, rate) in brackets) {
      if (base <= upper) return fixed + (base - lower) * rate;
      lower = upper;
    }
    return 0;
  }

  /// 근로소득세액공제(총급여에 따른 한도 포함).
  static double earnedIncomeCredit(double computed, double a) {
    final credit = computed <= 1300000
        ? computed * 0.55
        : 715000 + (computed - 1300000) * 0.30;
    final double limit;
    if (a <= 33000000) {
      limit = 740000;
    } else if (a <= 70000000) {
      final v = 740000 - (a - 33000000) * 0.008;
      limit = v < 660000 ? 660000 : v;
    } else if (a <= 120000000) {
      final v = 660000 - (a - 70000000) * 0.5;
      limit = v < 500000 ? 500000 : v;
    } else {
      final v = 500000 - (a - 120000000) * 0.5;
      limit = v < 200000 ? 200000 : v;
    }
    return credit < limit ? credit : limit;
  }
}
