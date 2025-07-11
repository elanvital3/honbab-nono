import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import 'common_card.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Widget? action;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      padding: AppPadding.all24,
      color: AppDesignTokens.surfaceContainer,
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: AppDesignTokens.primary.withOpacity(0.5),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDesignTokens.spacing1),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppDesignTokens.spacing3),
            action!,
          ],
        ],
      ),
    );
  }
}