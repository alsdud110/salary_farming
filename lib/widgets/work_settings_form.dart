import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../salary_calculator.dart';
import '../tax.dart';
import '../theme.dart';
import 'time_wheel_sheet.dart';

/// 입력 중인 근무 설정. 온보딩 단계들과 설정 수정 화면이 함께 쓴다.
class SettingsDraft extends ChangeNotifier {
  SettingsDraft([WorkSettings? s])
    : jobType = s?.jobType ?? JobType.fullTime,
      payBasis = s?.payBasis ?? JobType.fullTime.payBases.first,
      amount = TextEditingController(text: s == null ? '' : comma(s.payAmount)),
      withholding = s?.withholding ?? false,
      weekdays = {
        ...(s?.workWeekdays ?? const {1, 2, 3, 4, 5}),
      },
      start = s?.startMinute ?? 9 * 60,
      end = s?.endMinute ?? 18 * 60,
      hasBreak = s?.hasBreak ?? true,
      paidBreak = s?.paidBreak ?? true,
      breakStart = s != null && s.hasBreak ? s.breakStartMinute : 12 * 60,
      breakEnd = s != null && s.hasBreak ? s.breakEndMinute : 13 * 60;

  JobType jobType;
  PayBasis payBasis;
  final TextEditingController amount;
  bool withholding;
  final Set<int> weekdays;
  int start;
  int end;
  bool hasBreak;

  /// 휴게시간에도 급여가 쌓이는지.
  bool paidBreak;
  int breakStart;
  int breakEnd;

  /// 마지막으로 다음/저장을 눌렀을 때 막힌 이유.
  String? error;

  int? get amountValue => parseAmount(amount.text);

  void update(VoidCallback change) {
    change();
    error = null;
    notifyListeners();
  }

  void selectJob(JobType j) => update(() {
    if (j == jobType) return;
    jobType = j;
    withholding = j.defaultWithholding;
    if (!j.payBases.contains(payBasis)) {
      payBasis = j.payBases.first;
      amount.clear();
    }
  });

  void selectBasis(PayBasis b) => update(() {
    if (b == payBasis) return;
    payBasis = b;
    amount.clear();
  });

  /// 세전 연봉으로 추정한 실수령액이 실제와 다를 때, 세후 월급 직접 입력으로 바꾼다.
  /// 추정치를 미리 채워 두어 고치기만 하면 되게 한다.
  void useManualNet(int estimate) => update(() {
    payBasis = PayBasis.monthlyNet;
    amount.text = comma(estimate);
  });

  String? payError() =>
      WorkSettings.validatePay(payBasis: payBasis, payAmount: amountValue);

  String? timeError() => WorkSettings.validateTime(
    workWeekdays: weekdays,
    startMinute: start,
    endMinute: end,
    hasBreak: hasBreak,
    breakStartMinute: breakStart,
    breakEndMinute: breakEnd,
  );

  String? validate() => payError() ?? timeError();

  /// [check] 결과를 화면에 띄우고, 통과했는지 돌려준다.
  bool check(String? Function() check) {
    error = check();
    notifyListeners();
    return error == null;
  }

  WorkSettings build() => WorkSettings(
    jobType: jobType,
    payBasis: payBasis,
    payAmount: amountValue!,
    withholding: payBasis.canWithhold && withholding,
    nonTaxableMonthly: payBasis.usesPayrollTax
        ? WorkSettings.defaultNonTaxableMonthly
        : 0,
    workWeekdays: {...weekdays},
    startMinute: start,
    endMinute: end,
    breakStartMinute: hasBreak ? breakStart : 0,
    breakEndMinute: hasBreak ? breakEnd : 0,
    paidBreak: paidBreak,
  );

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }
}

/// 설정 수정 화면에서 쓰는 한 장짜리 폼.
class WorkSettingsForm extends StatefulWidget {
  const WorkSettingsForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
    required this.today,
  });

  final WorkSettings? initial;
  final String submitLabel;
  final ValueChanged<WorkSettings> onSubmit;
  final DateTime today;

  @override
  State<WorkSettingsForm> createState() => _WorkSettingsFormState();
}

class _WorkSettingsFormState extends State<WorkSettingsForm> {
  late final SettingsDraft _draft = SettingsDraft(widget.initial);

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_draft.check(_draft.validate)) return;
    widget.onSubmit(_draft.build());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('직업군'),
          JobTypePicker(draft: _draft),
          const SizedBox(height: 28),
          PayFields(draft: _draft),
          const SizedBox(height: 28),
          WorkTimeFields(draft: _draft),
          const SizedBox(height: 20),
          if (_draft.validate() == null)
            BasisCard(settings: _draft.build(), today: widget.today),
          if (_draft.error != null) ...[
            const SizedBox(height: 12),
            ErrorBox(_draft.error!),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ],
      ),
    );
  }
}

/// 직업군 고르기. 장부처럼 한 칸 안에 줄을 그어 나열한다.
/// 고른 줄은 왼쪽에 풀색 막대가 서고 바탕이 옅게 물든다.
class JobTypePicker extends StatelessWidget {
  const JobTypePicker({super.key, required this.draft});

  final SettingsDraft draft;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            for (var i = 0; i < JobType.values.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _JobRow(
                job: JobType.values[i],
                selected: draft.jobType == JobType.values[i],
                onTap: () => draft.selectJob(JobType.values[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.selected,
    required this.onTap,
  });

  final JobType job;
  final bool selected;
  final VoidCallback onTap;

  /// 직업군마다 무엇으로 급여를 넣는지 한 줄로.
  String get _pays => job.payBases.map((b) => b.label).join(' · ');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${job.label}, ${job.description}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        color: selected ? context.colors.salarySoft : context.colors.card,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ExcludeSemantics(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 4,
                      color: selected
                          ? context.colors.salary
                          : Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              job.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          Text(
                            _pays,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? context.colors.fieldText
                                  : context.colors.inkSoft,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _Radio(selected: selected),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 고르면 안쪽 점이 톡 튀어나오는 라디오.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? context.colors.salary : context.colors.line,
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          curve: selected ? Curves.easeOutCubic : Curves.easeIn,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: context.colors.salary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// 급여 방식·금액·공제 옵션.
class PayFields extends StatelessWidget {
  const PayFields({super.key, required this.draft});

  final SettingsDraft draft;

  String _helper(int? amount) {
    final basis = draft.payBasis;
    if (basis == PayBasis.hourly &&
        amount != null &&
        amount < minimumWage2026) {
      return '2026년 최저시급은 ${won(minimumWage2026)}이에요';
    }
    if (amount != null && amount >= 10000) {
      return '${basis.amountLabel} ${wonReadable(amount)}';
    }
    return switch (basis) {
      PayBasis.annualGross => '계약서에 적힌 세전 연봉. 세금은 자동으로 떼서 계산해요',
      PayBasis.monthlyNet => '통장에 찍히는 금액을 넣으면 그대로 계산해요',
      PayBasis.hourly => '2026년 최저시급 ${won(minimumWage2026)}',
      PayBasis.daily => '하루 일하고 받는 금액',
      PayBasis.monthlyGross => '한 달 계약 금액(세전)',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final basis = draft.payBasis;
        final amount = draft.amountValue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('급여 방식'),
            SegmentedButton<PayBasis>(
              showSelectedIcon: false,
              segments: [
                for (final b in draft.jobType.payBases)
                  ButtonSegment(value: b, label: Text(b.label)),
              ],
              selected: {basis},
              onSelectionChanged: (v) => draft.selectBasis(v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('payAmount'),
              controller: draft.amount,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
              ),
              decoration: InputDecoration(
                labelText: basis.amountLabel,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: basis.hint,
                hintStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: context.colors.inkSoft,
                ),
                suffixText: '원',
                helperText: _helper(amount),
              ),
              onChanged: (_) => draft.update(() {}),
            ),
            if (basis.canWithhold) ...[
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  title: const Text(
                    '3.3% 떼고 계산',
                    style: TextStyle(fontSize: 16),
                  ),
                  subtitle: const Text('사업소득 원천징수(소득세 3% + 지방세 0.3%)'),
                  value: draft.withholding,
                  onChanged: (v) => draft.update(() => draft.withholding = v),
                ),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: draft.payError() == null
                    ? _NetCheck(key: ValueKey(basis), draft: draft)
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 입력한 급여로 계산한 월 실수령액. 세전 연봉이면 "맞나요?" 를 묻고,
/// 다르면 세후 월급을 직접 넣게 한다.
class _NetCheck extends StatelessWidget {
  const _NetCheck({super.key, required this.draft});

  final SettingsDraft draft;

  @override
  Widget build(BuildContext context) {
    final basis = draft.payBasis;
    if (!basis.isMonthly || basis == PayBasis.monthlyNet) {
      return const SizedBox.shrink();
    }
    final net = SalaryCalculator.monthlyNet(draft.build())!.round();
    final asking = basis.usesPayrollTax;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: context.colors.salarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asking ? '세금 떼면 한 달에' : '3.3% 떼면 한 달에',
              style: TextStyle(color: context.colors.fieldText, fontSize: 13),
            ),
            const SizedBox(height: 2),
            TweenAnimationBuilder<double>(
              tween: Tween(end: net.toDouble()),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '약 ${won(v.round())}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
                    if (asking)
                      const TextSpan(
                        text: '  맞나요?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: TextStyle(color: context.colors.fieldText),
              ),
            ),
            if (asking) ...[
              const SizedBox(height: 4),
              Text(
                '2026년 4대보험·소득세 기준 추정이에요. 실제 통장에 찍히는 금액과 다르면 직접 넣어 주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: context.colors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => draft.useManualNet(net),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: context.colors.card,
                  foregroundColor: context.colors.fieldText,
                  side: BorderSide(color: context.colors.salary, width: 1.5),
                  textStyle: const TextStyle(
                    fontFamily: appFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('아니요, 직접 입력할게요'),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 근무 요일·출퇴근·휴게시간.
class WorkTimeFields extends StatelessWidget {
  const WorkTimeFields({super.key, required this.draft});

  final SettingsDraft draft;

  Future<void> _pickTime(
    BuildContext context,
    String label,
    int current,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await showTimeWheel(
      context,
      title: '$label 시간',
      initialMinute: current,
    );
    if (picked == null) return;
    draft.update(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('근무 요일'),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 8),
                Expanded(
                  child: _DayToggle(
                    label: weekdayLabels[d - 1],
                    selected: draft.weekdays.contains(d),
                    onTap: () => draft.update(() {
                      draft.weekdays.contains(d)
                          ? draft.weekdays.remove(d)
                          : draft.weekdays.add(d);
                    }),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          const FieldLabel('근무 시간'),
          Card(
            child: Column(
              children: [
                _TimeRow(
                  label: '출근',
                  value: draft.start,
                  onTap: () => _pickTime(
                    context,
                    '출근',
                    draft.start,
                    (v) => draft.start = v,
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                _TimeRow(
                  label: '퇴근',
                  value: draft.end,
                  onTap: () =>
                      _pickTime(context, '퇴근', draft.end, (v) => draft.end = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  title: const Text('휴게시간(점심)', style: TextStyle(fontSize: 16)),
                  subtitle: const Text('쉬는 시간이 있으면 켜 주세요'),
                  value: draft.hasBreak,
                  onChanged: (v) => draft.update(() => draft.hasBreak = v),
                ),
                if (draft.hasBreak) ...[
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    key: const ValueKey('paidBreak'),
                    contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    title: const Text(
                      '휴게시간에도 급여 쌓기',
                      style: TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      draft.paidBreak
                          ? '출근부터 퇴근까지 쉬지 않고 쌓여요'
                          : '휴게시간에는 멈췄다가 끝나면 다시 쌓여요',
                    ),
                    value: draft.paidBreak,
                    onChanged: (v) => draft.update(() => draft.paidBreak = v),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _TimeRow(
                    label: '휴게 시작',
                    value: draft.breakStart,
                    onTap: () => _pickTime(
                      context,
                      '휴게 시작',
                      draft.breakStart,
                      (v) => draft.breakStart = v,
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _TimeRow(
                    label: '휴게 종료',
                    value: draft.breakEnd,
                    onTap: () => _pickTime(
                      context,
                      '휴게 종료',
                      draft.breakEnd,
                      (v) => draft.breakEnd = v,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 급여가 어떤 기준으로 계산되는지 보여주는 카드.
class BasisCard extends StatelessWidget {
  const BasisCard({super.key, required this.settings, required this.today});

  final WorkSettings settings;
  final DateTime today;

  String _explain(WorkSettings s) {
    final withholding = s.appliesWithholding ? '3.3%를 뗀 금액을 ' : '';
    final paid = s.paidBreak || !s.hasBreak;
    final spread = paid ? '출근부터 퇴근까지 고르게 쌓여요' : '휴게시간을 뺀 근무 시간 동안 고르게 쌓여요';
    return switch (s.payBasis) {
      PayBasis.annualGross =>
        '세전 연봉을 12개월로 나눈 뒤 2026년 기준 4대보험(국민연금 4.75%, 건강보험 3.595%, '
            '장기요양, 고용보험 0.9%)과 근로소득 간이세액표 방식의 소득세·지방소득세를 떼서 '
            '월 실수령액을 추정했어요(본인 1명, 식대 20만원 비과세 가정). 이를 이번 달 근무일 수로 '
            '나눠 하루치를 정하고, $spread. '
            '실제 실수령액과 다르면 설정에서 세후 월급으로 바꿔 직접 넣을 수 있어요.',
      PayBasis.monthlyNet =>
        '입력한 실수령액을 이번 달 근무일 수로 나눠 하루치를 정하고, '
            '$spread.',
      PayBasis.monthlyGross =>
        '${withholding.isEmpty ? '월 계약금을' : '월 계약금에서 3.3%를 뗀 금액을'} '
            '이번 달 근무일 수로 나눠 하루치를 정하고, '
            '$spread.',
      PayBasis.hourly =>
        '시급 × ${paid ? '출근부터 퇴근까지(휴게시간 포함)' : '휴게시간을 뺀 근무 시간'}이 하루치예요. '
            '${withholding.isEmpty ? '' : '여기서 3.3%를 떼요. '}'
            '주휴수당은 넣지 않았어요.',
      PayBasis.daily =>
        '일당${withholding.isEmpty ? '' : '에서 3.3%를 뗀 금액'}이 하루치이고, '
            '$spread.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final workdays = SalaryCalculator.workdaysInMonth(s, today);
    final workday = _sampleWorkday(s, today);
    final perDay = SalaryCalculator.dailyPay(s, workday);
    final perHour = perDay / (s.paidMinutesPerDay / 60);
    final perSecond = perDay / (s.paidMinutesPerDay * 60);
    final expected = SalaryCalculator.expectedInMonth(s, today);
    final payroll = SalaryCalculator.payroll(s);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.salarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계산 기준',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.colors.fieldText,
            ),
          ),
          const SizedBox(height: 12),
          if (payroll != null) ...[
            _DeductionTable(payroll: payroll),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: context.colors.line),
            ),
          ],
          if (s.payBasis == PayBasis.monthlyGross && s.appliesWithholding) ...[
            _BasisRow('월 계약금', won(s.payAmount)),
            _BasisRow(
              '3.3% 원천징수',
              '-${won((s.payAmount * TaxCalculator.withholdingRate).round())}',
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: context.colors.line),
            ),
          ],
          _BasisRow('${today.month}월 근무일', '$workdays일'),
          _BasisRow('하루 근무', duration(s.workMinutesPerDay)),
          _BasisRow('하루에', '약 ${won(perDay.round())}'),
          _BasisRow('1시간에', '약 ${won(perHour.round())}'),
          _BasisRow('1초에', '약 ${perSecond.toStringAsFixed(2)}원'),
          _BasisRow(
            '${today.month}월 예상 실수령',
            '약 ${won(expected.round())}',
            strong: true,
          ),
          const SizedBox(height: 8),
          Text(
            _explain(s),
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  /// 하루치를 보여줄 근무일. 오늘이 쉬는 날이어도 같은 달 근무일 기준으로 보여준다.
  static DateTime _sampleWorkday(WorkSettings s, DateTime today) {
    for (var i = 0; i < 7; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      if (SalaryCalculator.isWorkday(s, d) && d.month == today.month) return d;
    }
    for (var i = 1; i < 7; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      if (SalaryCalculator.isWorkday(s, d)) return d;
    }
    return today;
  }
}

class _DeductionTable extends StatelessWidget {
  const _DeductionTable({required this.payroll});

  final PayrollDeduction payroll;

  @override
  Widget build(BuildContext context) {
    final p = payroll;
    String minus(int v) => '-${won(v)}';
    return Column(
      children: [
        _BasisRow('월 세전', won(p.gross)),
        _BasisRow('국민연금', minus(p.pension)),
        _BasisRow('건강보험', minus(p.health)),
        _BasisRow('장기요양', minus(p.longTermCare)),
        _BasisRow('고용보험', minus(p.employment)),
        _BasisRow('소득세', minus(p.incomeTax)),
        _BasisRow('지방소득세', minus(p.localTax)),
        _BasisRow('월 실수령(추정)', won(p.net), strong: true),
      ],
    );
  }
}

class _BasisRow extends StatelessWidget {
  const _BasisRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? context.colors.ink : context.colors.inkSoft,
                fontWeight: strong ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
              color: strong ? context.colors.fieldText : context.colors.ink,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 옅은 빨강 바탕. 다크에서는 어두운 바탕에 빨강을 살짝 섞는다.
        color: Theme.of(context).brightness == Brightness.dark
            ? context.colors.danger.withValues(alpha: 0.16)
            : const Color(0xFFF8E3DE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: context.colors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.colors.danger, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label요일',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? context.colors.salary : context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? context.colors.salary : context.colors.line,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Center(
                child: ExcludeSemantics(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: appFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : context.colors.inkSoft,
                    ),
                    child: Text(label),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            clock(value),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: context.colors.inkSoft),
        ],
      ),
      onTap: onTap,
    );
  }
}
