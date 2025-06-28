import 'package:flutter/material.dart';
import '../constants/app_design_tokens.dart';

class AppTextStyles {
  // Display 스타일 (큰 제목)
  static const TextStyle displayLarge = TextStyle(
    fontSize: AppDesignTokens.fontSizeH1,
    fontWeight: AppDesignTokens.fontWeightBold,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  // Headline 스타일 (섹션 제목)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: AppDesignTokens.fontSizeH2,
    fontWeight: AppDesignTokens.fontWeightSemiBold,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: AppDesignTokens.fontSizeH3,
    fontWeight: AppDesignTokens.fontWeightSemiBold,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  // Title 스타일 (카드 제목, AppBar 제목)
  static const TextStyle titleLarge = TextStyle(
    fontSize: AppDesignTokens.fontSizeH3,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: AppDesignTokens.fontSizeBody,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: AppDesignTokens.fontSizeBodySmall,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  // Body 스타일 (본문)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: AppDesignTokens.fontSizeBody,
    fontWeight: AppDesignTokens.fontWeightRegular,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: AppDesignTokens.fontSizeBodySmall,
    fontWeight: AppDesignTokens.fontWeightRegular,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: AppDesignTokens.fontSizeCaption,
    fontWeight: AppDesignTokens.fontWeightRegular,
    color: AppDesignTokens.onSurfaceVariant,
    fontFamily: 'NotoSansKR',
  );

  // Label 스타일 (버튼, 칩)
  static const TextStyle labelLarge = TextStyle(
    fontSize: AppDesignTokens.fontSizeBodySmall,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: AppDesignTokens.fontSizeCaption,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurface,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: AppDesignTokens.fontSizeSmall,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurfaceVariant,
    fontFamily: 'NotoSansKR',
  );

  // Special 스타일 (특수 용도)
  static const TextStyle caption = TextStyle(
    fontSize: AppDesignTokens.fontSizeCaption,
    fontWeight: AppDesignTokens.fontWeightRegular,
    color: AppDesignTokens.onSurfaceVariant,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle overline = TextStyle(
    fontSize: AppDesignTokens.fontSizeSmall,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.onSurfaceVariant,
    fontFamily: 'NotoSansKR',
    letterSpacing: 0.5,
  );

  // Primary Color 버전 (베이지 컬러)
  static const TextStyle headlinePrimary = TextStyle(
    fontSize: AppDesignTokens.fontSizeH2,
    fontWeight: AppDesignTokens.fontWeightSemiBold,
    color: AppDesignTokens.primary,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle titlePrimary = TextStyle(
    fontSize: AppDesignTokens.fontSizeH3,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.primary,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle labelPrimary = TextStyle(
    fontSize: AppDesignTokens.fontSizeBodySmall,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: AppDesignTokens.primary,
    fontFamily: 'NotoSansKR',
  );

  // White 버전 (어두운 배경용)
  static const TextStyle titleWhite = TextStyle(
    fontSize: AppDesignTokens.fontSizeH3,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: Colors.white,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle bodyWhite = TextStyle(
    fontSize: AppDesignTokens.fontSizeBody,
    fontWeight: AppDesignTokens.fontWeightRegular,
    color: Colors.white,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle labelWhite = TextStyle(
    fontSize: AppDesignTokens.fontSizeBodySmall,
    fontWeight: AppDesignTokens.fontWeightMedium,
    color: Colors.white,
    fontFamily: 'NotoSansKR',
  );
}

// 자주 사용하는 텍스트 스타일 확장
extension AppTextStyleExtensions on TextStyle {
  TextStyle get primary => copyWith(color: AppDesignTokens.primary);
  TextStyle get secondary => copyWith(color: AppDesignTokens.secondary);
  TextStyle get onSurfaceVariant => copyWith(color: AppDesignTokens.onSurfaceVariant);
  TextStyle get white => copyWith(color: Colors.white);
  
  TextStyle get bold => copyWith(fontWeight: AppDesignTokens.fontWeightBold);
  TextStyle get semiBold => copyWith(fontWeight: AppDesignTokens.fontWeightSemiBold);
  TextStyle get medium => copyWith(fontWeight: AppDesignTokens.fontWeightMedium);
  TextStyle get regular => copyWith(fontWeight: AppDesignTokens.fontWeightRegular);
}