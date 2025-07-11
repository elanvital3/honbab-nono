import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';

class CommonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? color;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool isSelected;

  const CommonCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.color,
    this.borderRadius,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isSelected 
        ? AppDesignTokens.primary.withOpacity(0.1)
        : color ?? AppDesignTokens.surface;

    Widget cardWidget = Container(
      margin: margin ?? AppDesignTokens.cardMargin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius ?? AppBorderRadius.medium,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isSelected 
            ? Border.all(color: AppDesignTokens.primary, width: 1)
            : null,
      ),
      child: Padding(
        padding: padding ?? AppDesignTokens.cardPadding,
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? AppBorderRadius.medium,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

// 특수한 용도의 카드 변형들
class InfoCard extends CommonCard {
  const InfoCard({
    super.key,
    required super.child,
    super.onTap,
  }) : super(
    padding: AppPadding.all12,
    margin: AppPadding.all8,
    elevation: AppDesignTokens.elevationLow,
    color: AppDesignTokens.surfaceContainer,
  );
}

class HighlightCard extends CommonCard {
  const HighlightCard({
    super.key,
    required super.child,
    super.onTap,
  }) : super(
    padding: AppPadding.all16,
    margin: AppPadding.vertical8,
    elevation: AppDesignTokens.elevationMedium,
    borderRadius: AppBorderRadius.large,
  );
}