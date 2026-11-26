import 'package:flutter/material.dart';

import '../app_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/work_settings_form.dart';

/// 첫 실행 설정. 저장하고 나면 계산 기준을 한 번 보여준 뒤 홈으로 넘어간다.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.store, required this.onFinished});

  final AppStore store;
  final VoidCallback onFinished;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  WorkSettings? _saved;

  Future<void> _save(WorkSettings settings) async {
    await widget.store.saveSettings(settings);
    if (!mounted) return;
    setState(() => _saved = settings);
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return Scaffold(
      body: SafeArea(
        child: saved == null ? _buildForm() : _buildDone(saved),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Text('🌱', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        const Text(
          '월급파밍',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          '일하는 동안 월급이 자라는 걸 지켜보고,\n회사에서 주운 혜택까지 알뜰하게 거둬 보세요.',
          style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 32),
        WorkSettingsForm(
          submitLabel: '설정 완료',
          today: widget.store.now(),
          onSubmit: _save,
        ),
        const SizedBox(height: 16),
        const Text(
          '입력한 내용은 이 기기에만 저장되고 어디로도 전송되지 않아요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildDone(WorkSettings saved) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const Text('🌾', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text(
                  '밭 준비 끝!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  '설정이 저장됐어요. 이제부터 아래 기준으로 월급이 쌓여요.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 24),
                BasisCard(settings: saved, today: widget.store.now()),
                const SizedBox(height: 16),
                const Text(
                  '설정은 언제든 설정 탭에서 바꿀 수 있어요.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: widget.onFinished,
            child: const Text('파밍 시작하기'),
          ),
        ],
      ),
    );
  }
}
