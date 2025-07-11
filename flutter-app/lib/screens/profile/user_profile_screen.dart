import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user.dart' as app_user;
import '../../models/meeting.dart';
import '../../models/restaurant.dart';
import '../../services/meeting_service.dart';
import '../../services/restaurant_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/user_badge_chip.dart';
import '../restaurant/restaurant_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.isCurrentUser = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  List<Restaurant> _favoriteRestaurants = [];
  bool _isFavoritesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('🏗️ UserProfile: build 메서드 호출됨');
      print('  - isCurrentUser: ${widget.isCurrentUser}');
      print('  - 사용자 ID: ${widget.user.id}');
    }
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text(
          widget.isCurrentUser ? '내 프로필' : '프로필',
          style: AppTextStyles.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildProfileHeader(),
            _buildStats(),
            _buildRatings(),
            if (widget.isCurrentUser) _buildFavoriteRestaurants(),
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
                backgroundImage: widget.user.profileImageUrl != null && 
                                widget.user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.user.profileImageUrl!)
                    : null,
                child: widget.user.profileImageUrl == null || 
                       widget.user.profileImageUrl!.isEmpty
                    ? Text(
                        widget.user.name[0],
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppDesignTokens.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppDesignTokens.spacing4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: AppTextStyles.headlineMedium,
                    ),
                    if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                      const SizedBox(height: AppDesignTokens.spacing2),
                      Text(
                        widget.user.bio!,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // 특성 뱃지를 Row 밑에 배치
          if (widget.user.badges.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.spacing3),
            UserBadgesList(badgeIds: widget.user.badges),
          ],
        ],
      ),
    );
  }


  Widget _buildStats() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '활동 통계',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          StreamBuilder<List<Meeting>>(
            stream: MeetingService.getUserMeetingsStream(widget.user.id),
            builder: (context, snapshot) {
              // 실제 모임 데이터로 통계 계산
              int participatedCount = 0;
              int hostedCount = 0;
              double averageRating = widget.user.rating;
              
              if (snapshot.hasData) {
                final meetings = snapshot.data!;
                participatedCount = meetings.length;
                hostedCount = meetings.where((m) => m.hostId == widget.user.id).length;
              }
              
              return Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '참여한 모임',
                      '${participatedCount}회',
                      Icons.group,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '주최한 모임',
                      '${hostedCount}회',
                      Icons.star,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '평균 별점',
                      '${averageRating.toStringAsFixed(1)}점',
                      Icons.favorite,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppDesignTokens.primary,
          size: 24,
        ),
        const SizedBox(height: AppDesignTokens.spacing2),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: AppDesignTokens.fontWeightBold,
            color: AppDesignTokens.onSurface,
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing1),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppDesignTokens.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRatings() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '받은 평가',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          _buildRatingItem('⏰ 시간 준수', widget.user.rating),
          const SizedBox(height: AppDesignTokens.spacing2),
          _buildRatingItem('💬 대화 매너', widget.user.rating),
          const SizedBox(height: AppDesignTokens.spacing2),
          _buildRatingItem('🤝 재만남 의향', widget.user.rating),
        ],
      ),
    );
  }

  Widget _buildRatingItem(String label, double rating) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: AppDesignTokens.primary,
              size: 16,
            );
          }),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        Text(
          rating.toStringAsFixed(1),
          style: AppTextStyles.labelMedium.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }


  Future<void> _loadFavoriteRestaurants() async {
    if (!widget.isCurrentUser) return;
    
    setState(() {
      _isFavoritesLoading = true;
    });
    
    try {
      final restaurants = await RestaurantService.getFavoriteRestaurants(widget.user.id);
      if (mounted) {
        setState(() {
          _favoriteRestaurants = restaurants;
          _isFavoritesLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 맛집 로드 실패: $e');
      }
      if (mounted) {
        setState(() {
          _isFavoritesLoading = false;
        });
      }
    }
  }
  
  Widget _buildFavoriteRestaurants() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '즐겨찾기 맛집',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
              if (_favoriteRestaurants.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_favoriteRestaurants.length}개',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppDesignTokens.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          
          if (_isFavoritesLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_favoriteRestaurants.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 48,
                    color: AppDesignTokens.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '아직 즐겨찾기한 맛집이 없습니다',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _favoriteRestaurants.length,
                itemBuilder: (context, index) {
                  final restaurant = _favoriteRestaurants[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestaurantDetailScreen(
                            restaurant: restaurant,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 200,
                      margin: EdgeInsets.only(
                        right: index < _favoriteRestaurants.length - 1 
                            ? AppDesignTokens.spacing2 
                            : 0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppDesignTokens.outline.withOpacity(0.2),
                        ),
                      ),
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
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: restaurant.imageUrl != null
                                  ? Image.network(
                                      restaurant.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(
                                            Icons.restaurant,
                                            color: AppDesignTokens.onSurfaceVariant,
                                            size: 32,
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.restaurant,
                                        color: AppDesignTokens.onSurfaceVariant,
                                        size: 32,
                                      ),
                                    ),
                            ),
                          ),
                          // 정보
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    restaurant.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      if (restaurant.youtubeStats != null)
                                        Text(
                                          '📺 ${restaurant.youtubeStats!.mentionCount}회',
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      if (restaurant.googlePlaces?.rating != null) ...[
                                        if (restaurant.youtubeStats != null)
                                          const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 12,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              restaurant.googlePlaces!.rating!.toStringAsFixed(1),
                                              style: AppTextStyles.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }



}