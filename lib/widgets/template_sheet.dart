import 'package:flutter/material.dart';

import '../app_store.dart';
import '../default_templates.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';

/// 혜택 템플릿을 새로 만들거나 고치는 시트. [template] 이 null 이면 새로 만든다.
Future<void> showTemplateSheet(
  BuildContext context,
  AppStore store, {
  BenefitTemplate? template,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => _TemplateSheet(store: store, template: template),
  );
}

class _TemplateSheet extends StatefulWidget {
  const _TemplateSheet({required this.store, this.template});

  final AppStore store;
  final BenefitTemplate? template;

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _icon;
  late UseFrequency _frequency;
  String? _nameError;
  String? _amountError;

  bool get _isNew => widget.template == null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(text: t?.name ?? '');
    _amount = TextEditingController(text: t == null ? '' : comma(t.amount));
    _icon = t?.icon ?? iconChoices.first;
    _frequency = t?.frequency ?? UseFrequency.often;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = parseAmount(_amount.text);
    setState(() {
      _nameError = name.isEmpty ? '혜택 이름을 입력해 주세요.' : null;
      _amountError = amount == null
          ? '금액을 입력해 주세요.'
          : amount <= 0
              ? '금액은 1원 이상이어야 해요.'
              : null;
    });
    if (_nameError != null || _amountError != null) return;

    final t = widget.template;
    if (t == null) {
      await widget.store.addTemplate(
        name: name,
        icon: _icon,
        amount: amount!,
        frequency: _frequency,
      );
    } else {
      await widget.store.updateTemplate(t.copyWith(
        name: name,
        icon: _icon,
        amount: amount,
        frequency: _frequency,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final t = widget.template!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t.name} 템플릿을 지울까요?'),
        content: const Text('이미 적립한 기록은 그대로 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.removeTemplate(t.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final icons = [
      if (!iconChoices.contains(_icon)) _icon,
      ...iconChoices,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? '내 혜택 만들기' : '혜택 고치기',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              maxLength: 12,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '이름',
                hintText: '예: 법인카드 저녁',
                errorText: _nameError,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: InputDecoration(
                labelText: '한 번에 얼마',
                hintText: '2,000',
                suffixText: '원',
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 20),
            const Text('아이콘', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in icons)
                  _IconChoice(
                    icon: icon,
                    selected: icon == _icon,
                    onTap: () => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('얼마나 자주 받나요', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SegmentedButton<UseFrequency>(
              showSelectedIcon: false,
              segments: [
                for (final f in UseFrequency.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {_frequency},
              onSelectionChanged: (v) => setState(() => _frequency = v.first),
            ),
            const SizedBox(height: 6),
            const Text(
              '자주 받는 혜택일수록 홈 화면 앞쪽에 놓여요.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('저장')),
            if (!_isNew) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _delete,
                child: const Text(
                  '이 템플릿 지우기',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.benefitSoft : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.benefit : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
        ),
      ),
    );
  }
}
