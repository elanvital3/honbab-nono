import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final String suffix;
  final Color? backgroundColor;
  final Color? textColor;

  const CountBadge({
    super.key,
    required this.count,
    this.suffix = '개',
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppDesignTokens.primary.withOpacity(0.1),
        borderRadius: AppBorderRadius.medium,
      ),
      child: Text(
        '$count$suffix',
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor ?? AppDesignTokens.primary,
          fontWeight: AppDesignTokens.fontWeightSemiBold,
        ),
      ),
    );
  }
}