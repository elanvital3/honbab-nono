import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../styles/text_styles.dart';
import '../constants/app_design_tokens.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;
  final bool showDistance;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.onFavoriteToggle,
    this.isFavorite = false,
    this.showDistance = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppDesignTokens.primary.withOpacity(0.1),
          highlightColor: AppDesignTokens.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽 이미지 영역
                _buildRestaurantImage(),
                
                const SizedBox(width: 12),
                
                // 중앙 정보 영역
                Expanded(
                  child: _buildRestaurantInfo(),
                ),
                
                // 오른쪽 즐겨찾기 버튼
                _buildFavoriteButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantImage() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppDesignTokens.surfaceContainer,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: restaurant.imageUrl != null && restaurant.imageUrl!.isNotEmpty
            ? Image.network(
                restaurant.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderImage();
                },
              )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppDesignTokens.surfaceContainer,
      ),
      child: Icon(
        Icons.restaurant,
        size: 28,
        color: AppDesignTokens.primary.withOpacity(0.6),
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 식당명
        Text(
          restaurant.name,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // 카테고리
        Text(
          restaurant.shortCategory,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppDesignTokens.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 2),
        
        // 주소
        Text(
          restaurant.address,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppDesignTokens.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 6),
        
        // 하단 정보 (평점, 거리)
        Row(
          children: [
            // 평점
            if (restaurant.rating != null) ...[
              Icon(
                Icons.star,
                size: 14,
                color: Colors.amber[600],
              ),
              const SizedBox(width: 2),
              Text(
                restaurant.rating!.toStringAsFixed(1),
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            
            // 거리 (평점과 거리 사이에 구분점)
            if (restaurant.rating != null && showDistance && restaurant.formattedDistance.isNotEmpty) ...[
              Text(
                ' • ',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                ),
              ),
            ],
            
            // 거리
            if (showDistance && restaurant.formattedDistance.isNotEmpty)
              Text(
                restaurant.formattedDistance,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    if (onFavoriteToggle == null) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: onFavoriteToggle,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: isFavorite 
              ? Colors.red[400] 
              : AppDesignTokens.onSurfaceVariant,
        ),
      ),
    );
  }
}