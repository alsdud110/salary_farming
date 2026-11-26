import 'package:flutter/material.dart';

import '../app_store.dart';
import '../format.dart';
import '../theme.dart';
import 'benefit_glyph.dart';

/// 많이 파밍한 혜택 1~3위를 3칸 타일로. 결산 화면과 공유 이미지에서 같이 쓴다.
class TopBenefitRow extends StatelessWidget {
  const TopBenefitRow({super.key, required this.summaries});

  /// 금액 순으로 정렬된 집계. 앞의 3개만 쓴다.
  final List<BenefitSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final top = summaries.take(3).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: i < top.length
                ? _TopBenefit(rank: i + 1, summary: top[i])
                : const SizedBox(),
          ),
        ],
      ],
    );
  }
}

/// 많이 파밍한 혜택 한 칸. 흰 바탕 위라 아이콘이 또렷하게 보인다.
class _TopBenefit extends StatelessWidget {
  const _TopBenefit({required this.rank, required this.summary});

  final int rank;
  final BenefitSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: surfaceBox(color: c.card, radius: 18),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              BenefitGlyph(s.icon, size: 44, bare: true),
              Positioned(
                left: -6,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.coin,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text('${s.count}번', style: TextStyle(color: c.inkSoft, fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              won(s.amount),
              style: TextStyle(
                color: c.benefitInk,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFeatures: tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
