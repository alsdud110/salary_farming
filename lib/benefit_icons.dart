import 'package:flutter/material.dart';

/// 혜택 아이콘 목록.
///
/// [key] 는 저장 값이다. 예전부터 이모지 문자열로 저장해 왔으므로 그대로 쓴다
/// (이미 저장된 템플릿·기록이 그대로 읽힌다). 화면에는 이모지를 그리지 않고
/// assets/icons/[asset].png 일러스트를, 아직 없으면 [fallback] 선 아이콘을 그린다.
class BenefitIcon {
  const BenefitIcon(
    this.key,
    this.asset,
    this.fallback,
    this.label, [
    this.tint = const Color(0xFF27875C),
  ]);

  final String key;
  final String asset;
  final IconData fallback;

  /// 아이콘 고유 색. 흰 바탕 위에서 3:1 이상(그래픽 요소 기준)이 되도록 골랐다.
  final Color tint;

  /// 시트 프롬프트·접근성용 설명.
  final String label;

  String get assetPath => 'assets/icons/$asset.png';
}

/// 시트 두 장(4×4)의 칸 순서와 같다. tool/make_icons.dart 가 이 순서로 자른다.
const benefitIconSheets = <String, List<BenefitIcon>>{
  'food': [
    BenefitIcon(
      '☕',
      'coffee',
      Icons.coffee_outlined,
      '김이 나는 커피 머그',
      Color(0xFF8D5A3B),
    ),
    BenefitIcon(
      '🍱',
      'lunchbox',
      Icons.lunch_dining_outlined,
      '도시락',
      Color(0xFFD96A1E),
    ),
    BenefitIcon(
      '🍪',
      'cookie',
      Icons.cookie_outlined,
      '초코칩 쿠키',
      Color(0xFFA8731E),
    ),
    BenefitIcon(
      '🥤',
      'drink',
      Icons.local_drink_outlined,
      '빨대 꽂힌 음료 컵',
      Color(0xFFD9466E),
    ),
    BenefitIcon(
      '🍜',
      'ramen',
      Icons.ramen_dining_outlined,
      '컵라면',
      Color(0xFFC96A1A),
    ),
    BenefitIcon(
      '🍚',
      'rice',
      Icons.rice_bowl_outlined,
      '밥그릇',
      Color(0xFF5E7487),
    ),
    BenefitIcon(
      '🍕',
      'pizza',
      Icons.local_pizza_outlined,
      '피자 조각',
      Color(0xFFD4552B),
    ),
    BenefitIcon('🍰', 'cake', Icons.cake_outlined, '조각 케이크', Color(0xFFC4508A)),
    BenefitIcon(
      '🍎',
      'apple',
      Icons.restaurant_outlined,
      '사과',
      Color(0xFFD0402F),
    ),
    BenefitIcon(
      '🧃',
      'juice',
      Icons.emoji_food_beverage_outlined,
      '빨대 꽂힌 주스 팩',
      Color(0xFFC98012),
    ),
    BenefitIcon(
      '🎁',
      'gift',
      Icons.card_giftcard_outlined,
      '리본 달린 선물 상자',
      Color(0xFF8E55C8),
    ),
    BenefitIcon(
      '🪙',
      'coin',
      Icons.paid_outlined,
      '원(₩) 표시 동전',
      Color(0xFFA8801A),
    ),
    BenefitIcon(
      '💰',
      'money',
      Icons.savings_outlined,
      '돈 주머니',
      Color(0xFF27875C),
    ),
    BenefitIcon(
      '🎉',
      'party',
      Icons.celebration_outlined,
      '파티 폭죽',
      Color(0xFFA548BD),
    ),
    BenefitIcon('🌱', 'sprout', Icons.eco_outlined, '새싹', Color(0xFF2F8F52)),
    BenefitIcon(
      '🎟️',
      'ticket',
      Icons.confirmation_number_outlined,
      '쿠폰 티켓',
      Color(0xFF3570C9),
    ),
  ],
  'office': [
    BenefitIcon(
      '🚌',
      'bus',
      Icons.directions_bus_outlined,
      '통근 버스',
      Color(0xFF2F72C4),
    ),
    BenefitIcon(
      '🚕',
      'taxi',
      Icons.local_taxi_outlined,
      '택시',
      Color(0xFFB07A10),
    ),
    BenefitIcon(
      '🅿️',
      'parking',
      Icons.local_parking_outlined,
      '주차 표지판(P)',
      Color(0xFF2B63C0),
    ),
    BenefitIcon(
      '⛽',
      'fuel',
      Icons.local_gas_station_outlined,
      '주유기',
      Color(0xFFC9483E),
    ),
    BenefitIcon(
      '🏋️',
      'dumbbell',
      Icons.fitness_center,
      '아령',
      Color(0xFF55657A),
    ),
    BenefitIcon(
      '💆',
      'massage',
      Icons.self_improvement_outlined,
      '안마의자',
      Color(0xFF7A5CC8),
    ),
    BenefitIcon(
      '🔋',
      'battery',
      Icons.battery_charging_full_outlined,
      '충전 중 배터리',
      Color(0xFF2F8F52),
    ),
    BenefitIcon(
      '🖨️',
      'printer',
      Icons.print_outlined,
      '프린터',
      Color(0xFF5A6878),
    ),
    BenefitIcon(
      '📚',
      'book',
      Icons.menu_book_outlined,
      '책 더미',
      Color(0xFF3E66B5),
    ),
    BenefitIcon(
      '💊',
      'pill',
      Icons.medication_outlined,
      '알약',
      Color(0xFFC9456F),
    ),
    BenefitIcon(
      '🧴',
      'lotion',
      Icons.sanitizer_outlined,
      '펌프 로션 병',
      Color(0xFF2C8C9C),
    ),
    BenefitIcon(
      '🧻',
      'tissue',
      Icons.wash_outlined,
      '두루마리 휴지',
      Color(0xFF6C7C8A),
    ),
    BenefitIcon(
      '☂️',
      'umbrella',
      Icons.umbrella_outlined,
      '우산',
      Color(0xFF5C4FC0),
    ),
    BenefitIcon(
      '💻',
      'laptop',
      Icons.laptop_outlined,
      '노트북',
      Color(0xFF4A5868),
    ),
    BenefitIcon(
      '👕',
      'shirt',
      Icons.checkroom_outlined,
      '티셔츠(유니폼)',
      Color(0xFF2F80B5),
    ),
    BenefitIcon(
      '📱',
      'phone',
      Icons.smartphone_outlined,
      '스마트폰',
      Color(0xFF34495E),
    ),
  ],
};

final List<BenefitIcon> benefitIcons = [
  for (final sheet in benefitIconSheets.values) ...sheet,
];

final Map<String, BenefitIcon> _byKey = {
  for (final i in benefitIcons) i.key: i,
};

/// 저장된 키에 맞는 아이콘. 모르는 키면 null.
BenefitIcon? benefitIconFor(String key) => _byKey[key];
