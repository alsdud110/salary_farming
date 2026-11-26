import 'package:flutter/material.dart';

/// Money Green 디자인 시스템.
///
/// 지정 팔레트
///   Primary #27875C · Secondary #BCE8C8 · Accent(골드) #E8B84A
///   Background #F6F8F2 · Surface #FFFFFF · Text #20382B · Text2 #607565
///
/// 접근성(WCAG AA, 본문 4.5:1 · 큰 글자 3:1)을 맞추려고 두 가지 짙은 변형을 더했다.
/// - [field] #1E7A50: 흰 글자를 얹는 면(메인 카드·버튼). Primary 위 흰 글자는 4.47:1 로
///   기준에 살짝 못 미쳐서 같은 계열을 한 단계 짙게 썼다(흰 글자 5.3:1).
/// - [benefitInk] #8A6410: 밝은 바탕 위 골드 글자(5.4:1). Accent 는 면·아이콘에만 쓴다.
/// 그 밖의 대비: ink 배경 위 12:1, inkSoft 배경 위 4.6:1·흰 바탕 4.9:1,
/// fieldMuted field 위 4.7:1, benefitOnDark field 위 3.8:1(큰 금액 전용).
class AppColors {
  const AppColors._();

  /// 화면 바탕.
  static const paper = Color(0xFFF6F8F2);

  /// 카드 면.
  static const card = Color(0xFFFFFFFF);

  static const ink = Color(0xFF20382B);
  static const inkSoft = Color(0xFF607565);

  /// 아주 옅은 구분선·입력칸 테두리.
  static const line = Color(0xFFE3EAE1);

  /// 옅은 초록 회색 칸(아이콘 바탕·빈 상태).
  static const shade = Color(0xFFEEF3EA);

  /// Primary. 진행 막대·아이콘·강조 글자·결산의 기본 수익 막대.
  static const salary = Color(0xFF27875C);

  /// Secondary. 진행 막대 바탕·고른 항목·탭 표시.
  static const secondary = Color(0xFFBCE8C8);

  /// 고른 항목·계산 기준 상자의 아주 옅은 초록 바탕.
  static const salarySoft = Color(0xFFE6F5EB);

  /// 흰 글자를 얹는 짙은 초록 면(메인 카드·버튼).
  static const field = Color(0xFF1E7A50);

  /// 짙은 초록 면 위의 보조 글자.
  static const fieldMuted = Color(0xFFE2F2E8);

  /// Accent 골드. 파밍 수익·파밍하기 버튼·보상.
  static const coin = Color(0xFFE8B84A);

  // 짙은 초록 면 안쪽.
  static const darkPanel = Color(0xFF2A8660);
  static const darkTrack = Color(0xFF3E9670);
  static const darkSub = Color(0xFFE2F2E8);
  static const darkText = Color(0xFFFFFFFF);

  /// 파밍 수익(회사에서 챙긴 돈). 막대·점 같은 면.
  static const benefit = Color(0xFFE8B84A);
  static const benefitSoft = Color(0xFFFBF2DC);

  /// 밝은 바탕 위의 파밍 수익 글자.
  static const benefitInk = Color(0xFF8A6410);

  /// 짙은 초록 면 위의 파밍 수익 금액(18px 이상 굵은 글자 전용).
  static const benefitOnDark = Color(0xFFF7D885);

  static const danger = Color(0xFFB3402E);
}

/// 둥근 모서리 크기.
class AppRadius {
  const AppRadius._();
  static const card = 20.0;
  static const tile = 18.0;
  static const button = 16.0;
}

/// 앱에 넣은 글꼴. 한 가족만 쓰고 굵기로 위계를 나눈다.
const appFont = 'Pretendard';

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.salary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.salary,
        onPrimary: Colors.white,
        secondary: AppColors.coin,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.danger,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFont,
  );
  final text = base.textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: appFont,
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    // 카드는 테두리·그림자 없이 흰 면과 둥근 모서리로만 구분한다.
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.field,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: text.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.card,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: text.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.field,
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.salary, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.salary : null,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.salary,
      linearTrackColor: AppColors.secondary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.secondary,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.field
              : AppColors.inkSoft,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: appFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w500
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.inkSoft,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: appFont,
        color: Colors.white,
        fontSize: 14,
      ),
      actionTextColor: AppColors.coin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.inkSoft,
        selectedBackgroundColor: AppColors.field,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size(0, 48),
        textStyle: text.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

/// 테두리·그림자 없이 흰 면과 둥근 모서리만 있는 카드 상자.
BoxDecoration surfaceBox({
  Color color = AppColors.card,
  double radius = AppRadius.card,
}) => BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius));
