import 'package:flutter/material.dart';
import '../models/user_badge.dart';
import '../constants/app_design_tokens.dart';
import '../styles/text_styles.dart';

class UserBadgeChip extends StatelessWidget {
  final String badgeId;
  final bool compact; // 작은 사이즈로 표시 여부

  const UserBadgeChip({
    super.key,
    required this.badgeId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final badge = UserBadge.getBadgeById(badgeId);
    
    if (badge == null) {
      return const SizedBox.shrink(); // 뱃지를 찾을 수 없으면 빈 위젯
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(
          color: AppDesignTokens.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            badge.emoji,
            style: TextStyle(fontSize: compact ? 12 : 14),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            badge.name,
            style: (compact ? AppTextStyles.bodySmall : AppTextStyles.bodyMedium).copyWith(
              color: AppDesignTokens.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class UserBadgesList extends StatelessWidget {
  final List<String> badgeIds;
  final bool compact;
  final int? maxDisplay; // 최대 표시할 뱃지 수 (null이면 모두 표시)
  final bool showMore; // "더보기" 표시 여부

  const UserBadgesList({
    super.key,
    required this.badgeIds,
    this.compact = false,
    this.maxDisplay,
    this.showMore = false,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayBadges = maxDisplay != null && badgeIds.length > maxDisplay!
        ? badgeIds.take(maxDisplay!).toList()
        : badgeIds;

    final remainingCount = maxDisplay != null && badgeIds.length > maxDisplay!
        ? badgeIds.length - maxDisplay!
        : 0;

    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: compact ? 4 : 6,
      children: [
        ...displayBadges.map((badgeId) => UserBadgeChip(
          badgeId: badgeId,
          compact: compact,
        )),
        
        if (remainingCount > 0 && showMore)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
            ),
            child: Text(
              '+$remainingCount',
              style: (compact ? AppTextStyles.bodySmall : AppTextStyles.bodyMedium).copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class BadgeCategoryDisplay extends StatelessWidget {
  final List<String> badgeIds;
  final String title;

  const BadgeCategoryDisplay({
    super.key,
    required this.badgeIds,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        UserBadgesList(badgeIds: badgeIds),
      ],
    );
  }
}