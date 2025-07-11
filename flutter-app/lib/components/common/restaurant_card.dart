import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../models/restaurant.dart';
import 'common_card.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: width ?? 200,
        height: height ?? 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                color: AppDesignTokens.surfaceContainer,
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  size: 32,
                  color: AppDesignTokens.primary.withOpacity(0.5),
                ),
              ),
            ),
            // 정보
            Expanded(
              child: Padding(
                padding: AppPadding.all12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      restaurant.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: AppDesignTokens.fontWeightSemiBold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      restaurant.category != null ? restaurant.category! : '기타',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}