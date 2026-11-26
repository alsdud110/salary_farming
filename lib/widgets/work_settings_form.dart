import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../salary_calculator.dart';
import '../theme.dart';

/// 급여·근무 시간 입력 폼. 첫 설정과 설정 수정에서 같이 쓴다.
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
  late final TextEditingController _amount;
  late PayCycle _cycle;
  late Set<int> _weekdays;
  late int _start;
  late int _end;
  late bool _hasBreak;
  late int _breakStart;
  late int _breakEnd;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _amount = TextEditingController(text: s == null ? '' : comma(s.payAmount));
    _cycle = s?.payCycle ?? PayCycle.monthly;
    _weekdays = {...(s?.workWeekdays ?? const {1, 2, 3, 4, 5})};
    _start = s?.startMinute ?? 9 * 60;
    _end = s?.endMinute ?? 18 * 60;
    _hasBreak = s?.hasBreak ?? true;
    _breakStart = s != null && s.hasBreak ? s.breakStartMinute : 12 * 60;
    _breakEnd = s != null && s.hasBreak ? s.breakEndMinute : 13 * 60;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validate() => WorkSettings.validate(
        payAmount: parseAmount(_amount.text),
        workWeekdays: _weekdays,
        startMinute: _start,
        endMinute: _end,
        hasBreak: _hasBreak,
        breakStartMinute: _breakStart,
        breakEndMinute: _breakEnd,
      );

  WorkSettings _build() => WorkSettings(
        payAmount: parseAmount(_amount.text)!,
        payCycle: _cycle,
        workWeekdays: {..._weekdays},
        startMinute: _start,
        endMinute: _end,
        breakStartMinute: _hasBreak ? _breakStart : 0,
        breakEndMinute: _hasBreak ? _breakEnd : 0,
      );

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(_build());
  }

  Future<void> _pickTime(int current, ValueChanged<int> onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      onPicked(picked.hour * 60 + picked.minute);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseAmount(_amount.text);
    final valid = _validate() == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('급여'),
        SegmentedButton<PayCycle>(
          showSelectedIcon: false,
          segments: [
            for (final c in PayCycle.values)
              ButtonSegment(value: c, label: Text(c.label)),
          ],
          selected: {_cycle},
          onSelectionChanged: (v) => setState(() => _cycle = v.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsFormatter()],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFeatures: tabular,
          ),
          decoration: InputDecoration(
            hintText: _cycle == PayCycle.monthly ? '3,000,000' : '700,000',
            suffixText: '원',
            helperText: amount != null && amount >= 10000
                ? '${_cycle.label} ${wonReadable(amount)}'
                : '세금을 뗀 실수령액을 넣으면 통장에 찍히는 돈과 맞아요',
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 28),
        const _Label('근무 요일'),
        Row(
          children: [
            for (var d = 1; d <= 7; d++) ...[
              if (d > 1) const SizedBox(width: 6),
              Expanded(
                child: _DayToggle(
                  label: weekdayLabels[d - 1],
                  selected: _weekdays.contains(d),
                  onTap: () => setState(() {
                    _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d);
                    _error = null;
                  }),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        const _Label('근무 시간'),
        Card(
          child: Column(
            children: [
              _TimeRow(
                label: '출근',
                value: _start,
                onTap: () => _pickTime(_start, (v) => _start = v),
              ),
              const Divider(indent: 16, endIndent: 16),
              _TimeRow(
                label: '퇴근',
                value: _end,
                onTap: () => _pickTime(_end, (v) => _end = v),
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
                title: const Text('휴게시간', style: TextStyle(fontSize: 16)),
                subtitle: const Text('이 시간에는 급여가 쌓이지 않아요'),
                value: _hasBreak,
                onChanged: (v) => setState(() {
                  _hasBreak = v;
                  _error = null;
                }),
              ),
              if (_hasBreak) ...[
                const Divider(indent: 16, endIndent: 16),
                _TimeRow(
                  label: '휴게 시작',
                  value: _breakStart,
                  onTap: () => _pickTime(_breakStart, (v) => _breakStart = v),
                ),
                const Divider(indent: 16, endIndent: 16),
                _TimeRow(
                  label: '휴게 종료',
                  value: _breakEnd,
                  onTap: () => _pickTime(_breakEnd, (v) => _breakEnd = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (valid) BasisCard(settings: _build(), today: widget.today),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8E3DE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

/// 급여가 어떤 기준으로 계산되는지 보여주는 카드.
class BasisCard extends StatelessWidget {
  const BasisCard({super.key, required this.settings, required this.today});

  final WorkSettings settings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final workdays = SalaryCalculator.workdaysInPeriod(s, today);
    final perDay = workdays == 0 ? 0.0 : s.payAmount / workdays;
    final perHour = perDay / (s.workMinutesPerDay / 60);
    final perSecond = perDay / (s.workMinutesPerDay * 60);
    final periodName = s.payCycle == PayCycle.monthly ? '이번 달' : '한 주';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.salarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계산 기준',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.field,
            ),
          ),
          const SizedBox(height: 10),
          _BasisRow('$periodName 근무일', '$workdays일'),
          _BasisRow('하루 근무', duration(s.workMinutesPerDay)),
          _BasisRow('하루에', '약 ${won(perDay.round())}'),
          _BasisRow('1시간에', '약 ${won(perHour.round())}'),
          _BasisRow('1초에', '약 ${perSecond.toStringAsFixed(2)}원'),
          const SizedBox(height: 8),
          Text(
            '${s.payCycle.label}을 $periodName 근무일 수로 나눠 하루치를 정하고, '
            '휴게시간을 뺀 근무 시간 동안 고르게 쌓여요. 세금과 공제는 계산하지 않아요.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _BasisRow extends StatelessWidget {
  const _BasisRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.inkSoft)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
      child: Material(
        color: selected ? AppColors.salary : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.salary : AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.inkSoft,
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
  const _TimeRow({required this.label, required this.value, required this.onTap});

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
              fontWeight: FontWeight.w700,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft),
        ],
      ),
      onTap: onTap,
    );
  }
}
