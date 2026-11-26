import 'package:flutter/material.dart';

import '../benefit_icons.dart';
import '../theme.dart';

var _precached = false;

/// 혜택 아이콘 그림을 앱 시작 때 한 번 미리 불러 둔다.
/// 처음 여는 화면에서 아이콘이 한 박자 늦게 나타나거나, 결산 이미지를 저장할 때
/// 아직 안 불러온 아이콘이 빠지는 일을 막는다. 그림 파일이 없는 아이콘은 조용히 건너뛴다.
void precacheBenefitIcons(BuildContext context) {
  if (_precached) return;
  _precached = true;
  for (final i in benefitIcons) {
    precacheImage(AssetImage(i.assetPath), context, onError: (_, _) {});
  }
}

/// 혜택 아이콘.
///
/// assets/icons/ 에 일러스트 PNG 가 있으면 그것을, 없으면 혜택마다 고유한 색의 아이콘을
/// 같은 색을 옅게 깐 둥근 칸 위에 그린다. 저장 값(이모지 문자열)은 그대로 두고 화면에서만
/// 바꿔 그리므로 기존 기록과 호환된다.
class BenefitGlyph extends StatelessWidget {
  const BenefitGlyph(
    this.icon, {
    super.key,
    this.size = 40,
    this.onDark = false,
    this.bare = false,
  });

  /// 저장된 아이콘 키(이모지 문자열).
  final String icon;
  final double size;

  /// 짙은 초록 면(결산 이미지 등) 위에 놓일 때.
  final bool onDark;

  /// 바탕 칸 없이 그림만(혜택 그리드·아이콘 고르기 칸).
  final bool bare;

  /// 일러스트가 없을 때 쓰는 아이콘.
  static IconData iconFor(String key) =>
      benefitIconFor(key)?.fallback ?? Icons.redeem_outlined;

  static Color tintFor(String key) =>
      benefitIconFor(key)?.tint ?? AppColors.salary;

  @override
  Widget build(BuildContext context) {
    final info = benefitIconFor(icon);
    final tint = onDark ? AppColors.benefitOnDark : tintFor(icon);
    final fallback = Icon(
      iconFor(icon),
      size: bare ? size * 0.78 : size * 0.52,
      color: tint,
    );
    final artSize = size * (bare ? 1 : 0.78);
    final art = info == null
        ? fallback
        : Image.asset(
            info.assetPath,
            width: artSize,
            height: artSize,
            filterQuality: FilterQuality.medium,
            semanticLabel: info.label,
            errorBuilder: (_, _, _) => fallback,
          );
    if (bare) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: art),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? AppColors.darkPanel : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: art,
    );
  }
}
