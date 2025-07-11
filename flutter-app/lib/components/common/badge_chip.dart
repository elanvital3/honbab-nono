import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';
import '../../models/user_badge.dart';

class BadgeChip extends StatelessWidget {
  final UserBadge badge;
  final bool isSelected;
  final VoidCallback? onTap;

  const BadgeChip({
    super.key,
    required this.badge,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignTokens.primary.withOpacity(0.1)
              : AppDesignTokens.surfaceContainer,
          borderRadius: AppBorderRadius.large,
          border: Border.all(
            color: isSelected
                ? AppDesignTokens.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badge.emoji,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.onSurface,
                fontWeight: isSelected
                    ? AppDesignTokens.fontWeightSemiBold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}