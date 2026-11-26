import 'package:flutter/material.dart';

import '../app_store.dart';
import '../format.dart';
import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/benefit_glyph.dart';
import '../widgets/brand_symbol.dart';
import '../widgets/template_sheet.dart';
import '../widgets/theme_toggle_tile.dart';
import '../widgets/work_settings_form.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 데이터를 지울까요?'),
        content: const Text('급여 설정, 혜택 템플릿, 적립 기록이 모두 사라지고 되살릴 수 없어요'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '모두 지우기',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await store.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.currentSettings;
        if (s == null) return const SizedBox.shrink();
        final days = [
          for (var d = 1; d <= 7; d++)
            if (s.workWeekdays.contains(d)) weekdayLabels[d - 1],
        ].join('·');

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  '설정',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text(
                        '급여와 근무 시간',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${s.jobType.label} · ${s.payBasis.label} ${wonReadable(s.payAmount)}\n'
                        '$days · ${clock(s.startMinute)} – ${clock(s.endMinute)}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => EditSettingsScreen(store: store),
                        ),
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: const Text(
                        '혜택 템플릿',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${store.templates.length}개'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TemplatesScreen(store: store),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ThemeToggleTile(
                isDark: store.darkTheme,
                onToggle: store.toggleTheme,
              ),
              const SizedBox(height: 12),
              _FarmEffectsCard(store: store),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.salarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기록은 이 기기에만 있어요',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.colors.fieldText,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '급여와 혜택 기록은 회원가입 없이 이 기기 안에만 저장되고 '
                      '어떤 서버로도 보내지 않아요.\n\n'
                      '그래서 앱을 지우거나 앱 데이터를 삭제하거나 기기를 바꾸면 '
                      '기록을 되살릴 수 없어요. 백업과 기기 간 동기화는 아직 없어요.',
                      style: TextStyle(fontSize: 13, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _confirmReset(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.danger,
                ),
                child: const Text('모든 데이터 지우기'),
              ),
              const SizedBox(height: 24),
              // 앱 정보
              Column(
                children: [
                  BrandSymbol(size: 48),
                  SizedBox(height: 8),
                  Text(
                    '월급파밍',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Salary Farming 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.inkSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 파밍 효과 켜고 끄기.
class _FarmEffectsCard extends StatelessWidget {
  const _FarmEffectsCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: padding,
            title: const Text(
              '파밍 애니메이션',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              reduced
                  ? '기기에서 동작 줄이기를 켜 두어 움직임 없이 보여줘요'
                  : '적립할 때 동전이 날아가고 금액이 올라가요',
            ),
            value: store.farmAnimation,
            onChanged: store.setFarmAnimation,
          ),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            contentPadding: padding,
            title: const Text(
              '햅틱 피드백',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('적립할 때 가볍게 진동해요'),
            value: store.farmHaptic,
            onChanged: store.setFarmHaptic,
          ),
        ],
      ),
    );
  }
}

/// 급여·근무 시간 수정.
class EditSettingsScreen extends StatelessWidget {
  const EditSettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('급여와 근무 시간')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              '바꾼 설정은 오늘부터 적용돼요. 어제까지의 급여 기록은 그대로예요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            WorkSettingsForm(
              initial: store.currentSettings,
              submitLabel: '저장',
              today: store.now(),
              onSubmit: (settings) async {
                final navigator = Navigator.of(context);
                await store.saveSettings(settings);
                if (!context.mounted) return;
                // 앱 맨 위 레이어에 띄우므로 화면을 닫아도 토스트는 남는다.
                showAppToast(context, '저장했어요. 오늘부터 새 기준으로 계산해요.');
                navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 혜택 템플릿 관리.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('혜택 템플릿')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTemplateSheet(context, store),
        backgroundColor: context.colors.inverse,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('직접 만들기'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final all = store.templates;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final c in BenefitCategory.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                    child: Text(
                      c.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _TemplateGroup(
                    store: store,
                    templates: all.where((t) => t.category == c).toList(),
                    emptyText: c == BenefitCategory.custom
                        ? '아직 직접 만든 혜택이 없어요'
                        : '이 분류의 템플릿을 모두 지웠어요',
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TemplateGroup extends StatelessWidget {
  const _TemplateGroup({
    required this.store,
    required this.templates,
    required this.emptyText,
  });

  final AppStore store;
  final List<BenefitTemplate> templates;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyText,
            style: TextStyle(color: context.colors.inkSoft),
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < templates.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: BenefitGlyph(templates[i].icon, size: 40),
              title: Text(
                templates[i].name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(templates[i].frequency.label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    won(templates[i].amount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: context.colors.inkSoft),
                ],
              ),
              onTap: () =>
                  showTemplateSheet(context, store, template: templates[i]),
            ),
          ],
        ],
      ),
    );
  }
}
