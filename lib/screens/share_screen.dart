import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../app_store.dart';
import '../format.dart';
import '../period.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/brand_symbol.dart';
import '../widgets/top_benefits.dart';

/// 결산 이미지에 무엇까지 보여줄지.
enum ShareScope {
  /// 급여를 짐작할 수 있는 정보는 빼고 파밍 수익만. 기본값.
  benefitOnly('파밍 수익만'),

  /// 기본 수익·파밍 수익·총 수확을 모두.
  all('전체 수익');

  const ShareScope(this.label);
  final String label;
}

/// 결산 이미지 미리보기. 여기서 기기에 저장하거나 다른 앱으로 공유한다.
class ShareScreen extends StatefulWidget {
  const ShareScreen({
    super.key,
    required this.period,
    required this.totals,
    required this.summaries,
  });

  final Period period;
  final PeriodTotals totals;
  final List<BenefitSummary> summaries;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;
  ShareScope _scope = ShareScope.benefitOnly;

  String get _fileName {
    final p = widget.period;
    String two(int v) => v.toString().padLeft(2, '0');
    return 'salary_farming_${p.kind.name}_'
        '${p.from.year}${two(p.from.month)}${two(p.from.day)}.png';
  }

  Future<Uint8List> _capture() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  void _toast(String message) {
    if (!mounted) return;
    showAppToast(context, message);
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    try {
      if (!await Gal.hasPermission()) {
        final granted = await Gal.requestPermission();
        if (!granted) {
          _toast('사진 저장 권한이 없어요. 기기 설정에서 사진 접근을 허용해 주세요.');
          return;
        }
      }
      final bytes = await _capture();
      await Gal.putImageBytes(bytes, name: _fileName.replaceAll('.png', ''));
      _toast('사진 앱에 저장했어요');
    } on GalException catch (e) {
      _toast(switch (e.type) {
        GalExceptionType.permissionDenied =>
          '사진 저장 권한이 없어요. 기기 설정에서 사진 접근을 허용해 주세요.',
        GalExceptionType.notEnoughSpace => '저장 공간이 부족해서 저장하지 못했어요',
        _ => '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
      });
    } catch (e) {
      _toast('저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  });

  Future<void> _share() => _run(() async {
    try {
      final bytes = await _capture();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: _fileName),
          ],
          fileNameOverrides: [_fileName],
          text: '월급파밍 ${widget.period.title}',
        ),
      );
    } catch (e) {
      _toast('공유 화면을 열지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('수확 결산 이미지')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SegmentedButton<ShareScope>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in ShareScope.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_scope},
                  onSelectionChanged: _busy
                      ? null
                      : (v) => setState(() => _scope = v.first),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    // 저장·공유는 이 경계를 그대로 찍으므로 미리보기와 같은 이미지가 나간다.
                    child: RepaintBoundary(
                      key: _cardKey,
                      // 공유 이미지는 앱 테마와 상관없이 늘 밝은 결산 카드로 만든다.
                      child: Theme(
                        data: buildTheme(),
                        child: SettlementCard(
                          period: widget.period,
                          totals: widget.totals,
                          summaries: widget.summaries,
                          scope: _scope,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  // 웹에는 사진 앱이 없어서 공유(내려받기)만 둔다.
                  if (!kIsWeb) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('저장'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('공유'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이미지로 내보내는 결산 카드.
///
/// 홈 화면과 같은 구성으로, 연한 바탕 위에 둥근 카드들을 얹는다. 바탕까지 함께 저장되므로
/// 공유한 이미지에서도 모서리가 둥글게 보인다.
///
/// [ShareScope.all]은 기본 수익과 파밍 수익을 끝까지 따로 적는다.
/// [ShareScope.benefitOnly]는 기본 수익·총 수확·급여 비중 문구를 그리지 않고
/// 파밍 수익을 가장 크게 보여준다.
class SettlementCard extends StatelessWidget {
  const SettlementCard({
    super.key,
    required this.period,
    required this.totals,
    required this.summaries,
    this.scope = ShareScope.benefitOnly,
  });

  final Period period;
  final PeriodTotals totals;
  final List<BenefitSummary> summaries;
  final ShareScope scope;

  @override
  Widget build(BuildContext context) {
    final top = summaries.take(3).toList();
    final benefitOnly = scope == ShareScope.benefitOnly;
    final insights = buildInsights(
      totals,
      summaries,
      includeSalary: !benefitOnly,
    );
    // 전체 수익은 예전처럼 한 줄, 파밍 수익만은 급여와 무관한 줄을 두 줄까지.
    final lines = insights.take(benefitOnly ? 2 : 1).toList();

    return Container(
      color: AppColors.paper,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 기간. 브랜드는 맨 아래에 한 번만 둔다.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${period.kind.label} 수확 결산',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (benefitOnly)
            _BenefitHero(period: period, totals: totals, summaries: summaries)
          else
            // 총 수확 카드(홈의 메인 카드와 같은 모양)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: surfaceBox(color: AppColors.field, radius: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${period.label} 총 수확',
                    style: const TextStyle(
                      color: AppColors.fieldMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      won(totals.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.darkTrack),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Split(
                          label: '기본 수익',
                          value: won(totals.salary),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Split(
                          label: '파밍 수익',
                          value:
                              '${totals.benefit > 0 ? '+' : ''}${won(totals.benefit)}',
                          color: AppColors.benefitOnDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 많이 파밍한 혜택: 홈의 혜택 칸과 같은 3칸 타일
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '많이 파밍한 혜택',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TopBenefitRow(summaries: top),
          ],

          // 파밍 일지 한마디: 말풍선
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: surfaceBox(color: AppColors.card, radius: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.salarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco,
                      size: 18,
                      color: AppColors.salary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '파밍 일지',
                          style: TextStyle(
                            color: AppColors.field,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        for (final line in lines) ...[
                          const SizedBox(height: 2),
                          Text(
                            line,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 브랜드: 심볼 + 월급파밍
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandSymbol(size: 26),
              SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  text: '월급파밍',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '으로 기록했어요',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.fieldMuted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              fontFeatures: tabular,
            ),
          ),
        ),
      ],
    );
  }
}

/// 파밍 수익만 공유할 때의 메인 카드. 급여·총 수확 대신 파밍 수익을 가장 크게,
/// 그 아래에 파밍 횟수와 챙긴 혜택 가짓수를 둔다.
class _BenefitHero extends StatelessWidget {
  const _BenefitHero({
    required this.period,
    required this.totals,
    required this.summaries,
  });

  final Period period;
  final PeriodTotals totals;
  final List<BenefitSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final count = summaries.fold<int>(0, (sum, s) => sum + s.count);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: surfaceBox(color: AppColors.field, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${period.label} 파밍 수익',
            style: const TextStyle(
              color: AppColors.fieldMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${totals.benefit > 0 ? '+' : ''}${won(totals.benefit)}',
              style: const TextStyle(
                color: AppColors.benefitOnDark,
                fontSize: 46,
                height: 1.15,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.darkTrack),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Split(
                  label: '파밍 횟수',
                  value: '$count번',
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Split(
                  label: '챙긴 혜택',
                  value: '${summaries.length}가지',
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
