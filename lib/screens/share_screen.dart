import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../app_store.dart';
import '../format.dart';
import '../period.dart';
import '../theme.dart';

/// 결산 이미지 미리보기. 여기서 기기에 저장하거나 다른 앱으로 공유한다.
class ShareScreen extends StatefulWidget {
  const ShareScreen({
    super.key,
    required this.period,
    required this.totals,
    required this.summaries,
    required this.insight,
  });

  final Period period;
  final PeriodTotals totals;
  final List<BenefitSummary> summaries;
  final String? insight;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
          _toast('사진 앱에 저장했어요.');
        } on GalException catch (e) {
          _toast(switch (e.type) {
            GalExceptionType.permissionDenied =>
              '사진 저장 권한이 없어요. 기기 설정에서 사진 접근을 허용해 주세요.',
            GalExceptionType.notEnoughSpace => '저장 공간이 부족해서 저장하지 못했어요.',
            _ => '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
          });
        } catch (e) {
          _toast('저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
        }
      });

  Future<void> _share() => _run(() async {
        try {
          final bytes = await _capture();
          await SharePlus.instance.share(ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'image/png', name: _fileName)],
            fileNameOverrides: [_fileName],
            text: '월급파밍 ${widget.period.title}',
          ));
        } catch (e) {
          _toast('공유 화면을 열지 못했어요. 잠시 후 다시 시도해 주세요.');
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('결산 이미지')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: SettlementCard(
                        period: widget.period,
                        totals: widget.totals,
                        summaries: widget.summaries,
                        insight: widget.insight,
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

/// 이미지로 내보내는 결산 카드. 급여와 혜택을 끝까지 따로 적는다.
class SettlementCard extends StatelessWidget {
  const SettlementCard({
    super.key,
    required this.period,
    required this.totals,
    required this.summaries,
    required this.insight,
  });

  final Period period;
  final PeriodTotals totals;
  final List<BenefitSummary> summaries;
  final String? insight;

  @override
  Widget build(BuildContext context) {
    const mist = Color(0xFFB9D4BD);
    const grain = Color(0xFFF2C66B);
    final top = summaries.take(3).toList();

    return Container(
      color: AppColors.field,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '🌾 월급파밍',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                period.kind.label,
                style: const TextStyle(
                  color: mist,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            period.label,
            style: const TextStyle(color: mist, fontSize: 14, fontFeatures: tabular),
          ),
          const SizedBox(height: 4),
          const Text(
            '회사에서 거둔 총 가치',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              won(totals.total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                height: 1.15,
                fontWeight: FontWeight.w900,
                fontFeatures: tabular,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF173A22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _CardRow(
                  dot: const Color(0xFF8FD19A),
                  label: '실제 급여',
                  value: won(totals.salary),
                  valueColor: Colors.white,
                ),
                const SizedBox(height: 10),
                _CardRow(
                  dot: grain,
                  label: '추가 혜택',
                  value: '+${won(totals.benefit)}',
                  valueColor: grain,
                ),
              ],
            ),
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '많이 주운 혜택',
              style: TextStyle(color: mist, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final s in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(s.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.name} ${s.count}번',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    Text(
                      won(s.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (insight != null) ...[
            const SizedBox(height: 20),
            Text(
              insight!,
              style: const TextStyle(
                color: grain,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'SALARY FARMING',
            style: TextStyle(
              color: Color(0xFF6F9477),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.dot,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final Color dot;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFD6E5D8), fontSize: 15),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFeatures: tabular,
          ),
        ),
      ],
    );
  }
}
