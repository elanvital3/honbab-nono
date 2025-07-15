import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user.dart' as app_user;
import '../../models/meeting.dart';
import '../../models/restaurant.dart';
import '../../services/meeting_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/evaluation_service.dart';
import 'user_comments_screen.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/count_badge.dart';
import '../../components/common/empty_state_card.dart';
import '../../components/common/restaurant_grid_card.dart';
import '../../components/common/stats_divider.dart';
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
            _buildComments(),
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
            Align(
              alignment: Alignment.centerLeft,
              child: UserBadgesList(badgeIds: widget.user.badges),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('활동 통계', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),
          StreamBuilder<List<Meeting>>(
            stream: MeetingService.getUserMeetingsStream(widget.user.id),
            builder: (context, snapshot) {
              // 실제 모임 데이터로 통계 계산
              int participatedCount = 0;
              int hostedCount = 0;
              double averageRating = widget.user.rating;
              
              if (snapshot.hasData) {
                final meetings = snapshot.data!;
                // 완료된 모임만 카운팅
                final completedMeetings = meetings.where((m) => m.status == 'completed').toList();
                participatedCount = completedMeetings.length;
                hostedCount = completedMeetings.where((m) => m.hostId == widget.user.id).length;
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
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRatings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('받은 평가', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),

          _buildRatingItem('⏰ 시간 준수', widget.user.rating),
          const SizedBox(height: 12),
          _buildRatingItem('💬 대화 매너', widget.user.rating),
          const SizedBox(height: 12),
          _buildRatingItem('🤝 재만남 의향', widget.user.rating),
        ],
      ),
    );
  }

  Widget _buildRatingItem(String label, double rating) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              );
            }),
          ),
        ),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16, // 14에서 16으로 증가 (평점 숫자 크기 개선)
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildComments() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('받은 코멘트', style: AppTextStyles.titleLarge),
              GestureDetector(
                onTap: () => _navigateToCommentsDetail(),
                child: Text(
                  '전체보기',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: EvaluationService.getUserComments(widget.user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Text(
                  '코멘트를 불러올 수 없습니다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                );
              }
              
              final comments = snapshot.data ?? [];
              
              if (comments.isEmpty) {
                return Text(
                  widget.isCurrentUser 
                    ? '아직 받은 코멘트가 없습니다'
                    : '아직 작성된 코멘트가 없습니다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                );
              }
              
              // 최근 2개 코멘트만 표시
              final recentComments = comments.take(2).toList();
              
              return Column(
                children: recentComments.map((comment) => _buildCommentPreview(comment)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentPreview(Map<String, dynamic> comment) {
    final String? restaurantName = comment['meetingRestaurant'] as String?;
    final String meetingLocation = comment['meetingLocation'] as String? ?? '알 수 없는 장소';
    final String commentText = comment['comment'] as String;
    final double rating = comment['averageRating'] as double? ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모임 정보
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  restaurantName ?? meetingLocation,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 평점
              if (rating > 0) ...[
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          
          // 코멘트 내용 (2줄까지만)
          Text(
            commentText,
            style: AppTextStyles.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToCommentsDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserCommentsScreen(
          userId: widget.user.id,
          isMyComments: widget.isCurrentUser,
        ),
      ),
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
                CountBadge(count: _favoriteRestaurants.length),
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
            EmptyStateCard(
              icon: Icons.favorite_border,
              message: '아직 즐겨찾기한 맛집이 없습니다',
              subtitle: '맛집을 즐겨찾기에 추가해보세요',
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _favoriteRestaurants.length,
                itemBuilder: (context, index) {
                  final restaurant = _favoriteRestaurants[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _favoriteRestaurants.length - 1 
                          ? AppDesignTokens.spacing2 
                          : 0,
                    ),
                    child: RestaurantGridCard(
                      restaurant: restaurant,
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