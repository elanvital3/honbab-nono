import 'package:flutter/material.dart';

class AppDesignTokens {
  // Spacing System (8px grid)
  static const double spacing1 = 4.0;   // 0.5x
  static const double spacing2 = 8.0;   // 1x - base unit
  static const double spacing3 = 12.0;  // 1.5x
  static const double spacing4 = 16.0;  // 2x - most common
  static const double spacing5 = 20.0;  // 2.5x
  static const double spacing6 = 24.0;  // 3x
  static const double spacing8 = 32.0;  // 4x
  static const double spacing10 = 40.0; // 5x

  // Border Radius
  static const double radiusSmall = 8.0;   // 작은 요소
  static const double radiusDefault = 12.0; // 기본 (카드, 버튼)
  static const double radiusLarge = 16.0;  // 큰 요소 (모달, 큰 카드)
  static const double radiusXL = 24.0;     // 매우 큰 요소

  // Typography Sizes
  static const double fontSizeH1 = 24.0;     // 페이지 제목
  static const double fontSizeH2 = 20.0;     // 섹션 제목
  static const double fontSizeH3 = 18.0;     // 카드 제목
  static const double fontSizeBody = 16.0;   // 본문
  static const double fontSizeBodySmall = 14.0; // 작은 본문
  static const double fontSizeCaption = 12.0;   // 설명, 라벨
  static const double fontSizeSmall = 10.0;     // 매우 작은 텍스트

  // Font Weights
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // Colors (기존 앱 컬러 유지)
  static const Color primary = Color(0xFFD2B48C);      // 베이지
  static const Color secondary = Color(0xFF666666);     // 회색
  static const Color background = Color(0xFFFFFFFF);    // 순백색
  static const Color surface = Color(0xFFFFFFFF);       // 순백색
  static const Color surfaceContainer = Color(0xFFF9F9F9); // 연한 회색
  static const Color onSurface = Color(0xFF000000);     // 검은색
  static const Color outline = Color(0xFF999999);       // 연한 회색
  static const Color onSurfaceVariant = Color(0xFF666666); // 보조 텍스트

  // Elevation & Shadows
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconDefault = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXL = 48.0;

  // Button Heights
  static const double buttonHeightSmall = 32.0;
  static const double buttonHeightDefault = 48.0;
  static const double buttonHeightLarge = 56.0;

  // AppBar
  static const double appBarHeight = 56.0;
  
  // Card
  static const EdgeInsets cardPadding = EdgeInsets.all(spacing4);
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: spacing4,
    vertical: spacing2,
  );
}

// 자주 사용하는 EdgeInsets 프리셋
class AppPadding {
  static const EdgeInsets all4 = EdgeInsets.all(AppDesignTokens.spacing1);
  static const EdgeInsets all8 = EdgeInsets.all(AppDesignTokens.spacing2);
  static const EdgeInsets all12 = EdgeInsets.all(AppDesignTokens.spacing3);
  static const EdgeInsets all16 = EdgeInsets.all(AppDesignTokens.spacing4);
  static const EdgeInsets all20 = EdgeInsets.all(AppDesignTokens.spacing5);
  static const EdgeInsets all24 = EdgeInsets.all(AppDesignTokens.spacing6);

  static const EdgeInsets horizontal16 = EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing4);
  static const EdgeInsets vertical8 = EdgeInsets.symmetric(vertical: AppDesignTokens.spacing2);
  static const EdgeInsets vertical16 = EdgeInsets.symmetric(vertical: AppDesignTokens.spacing4);
  
  static const EdgeInsets screenPadding = EdgeInsets.all(AppDesignTokens.spacing4);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: AppDesignTokens.spacing6,
    vertical: AppDesignTokens.spacing3,
  );
}

// 자주 사용하는 BorderRadius 프리셋
class AppBorderRadius {
  static const BorderRadius small = BorderRadius.all(Radius.circular(AppDesignTokens.radiusSmall));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(AppDesignTokens.radiusDefault));
  static const BorderRadius large = BorderRadius.all(Radius.circular(AppDesignTokens.radiusLarge));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(AppDesignTokens.radiusXL));
}