import 'package:flutter/material.dart';

/// 월급파밍 브랜드 심볼(동전 + 새싹). 혜택 아이콘(BenefitGlyph)과 역할이 다르니 섞어 쓰지 않는다.
///
/// 원본 색 그대로 그린다: 배경·테두리·그림자·색 필터를 얹지 않는다.
/// [size]는 높이이고, 너비는 그림 비율에 맞춰 정해져 찌그러지지 않는다.
class BrandSymbol extends StatelessWidget {
  const BrandSymbol({super.key, this.size = 32, this.semanticLabel});

  static const asset = 'assets/images/brand/brand_symbol.png';

  /// 에셋의 가로 ÷ 세로(841×945, 투명 여백을 잘라 낸 크기).
  static const aspectRatio = 841 / 945;

  final double size;

  /// 옆에 '월급파밍' 글자가 없을 때만 읽어 줄 이름을 준다. 없으면 꾸밈으로 보고 건너뛴다.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: size,
      width: size * aspectRatio,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
