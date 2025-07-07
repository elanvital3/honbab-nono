import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/restaurant.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../services/restaurant_service.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  bool _isFavorite = false;
  bool _isLoading = false;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await RestaurantService.isFavorite(widget.restaurant.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final newFavoriteStatus = await RestaurantService.toggleFavoriteWithData(widget.restaurant);
      if (mounted) {
        setState(() {
          _isFavorite = newFavoriteStatus;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newFavoriteStatus ? '즐겨찾기에 추가했습니다' : '즐겨찾기에서 제거했습니다'),
            backgroundColor: AppDesignTokens.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('즐겨찾기 처리에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _isLoading ? null : _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 가게이름 (큰 글씨)
            _buildRestaurantName(),
            
            const SizedBox(height: 6),
            
            // 평점 + 리뷰수 + YouTube 언급수 (한 줄)
            _buildCompactRatingInfo(),
            
            const SizedBox(height: 12),
            
            // 주소 + 바로가기 버튼들
            _buildAddressWithNavigation(),
            
            const SizedBox(height: 16),
            
            // 사진 갤러리
            _buildPhotoGallery(),
            
            const SizedBox(height: 16),
            
            // 특징 태그
            if (widget.restaurant.featureTags?.isNotEmpty == true)
              _buildFeatureTags(),
            
            const SizedBox(height: 24),
            
            // 영업시간 정보
            if (widget.restaurant.googlePlaces?.isOpen != null ||
                widget.restaurant.googlePlaces?.regularOpeningHours != null)
              _buildOpeningHoursSection(),
            
            const SizedBox(height: 16),
            
            // Google 리뷰 섹션 (리뷰가 있으면 표시)
            if (widget.restaurant.googlePlaces?.reviews.isNotEmpty == true) ...[
              _buildReviewsSection(),
              const SizedBox(height: 16),
            ],
            
            // 네이버 블로그 섹션 (블로그가 있으면 표시)
            if (widget.restaurant.naverBlog?.posts.isNotEmpty == true) ...[
              _buildNaverBlogSection(),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 32), // 하단 여백
          ],
        ),
      ),
    );
  }



  Widget _buildReviewsSection() {
    final reviews = widget.restaurant.googlePlaces!.reviews;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Google 리뷰',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        ...reviews.map((review) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesignTokens.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    review.authorName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(5, (index) => Icon(
                      Icons.star,
                      size: 14,
                      color: index < review.rating 
                          ? Colors.orange 
                          : Colors.grey.shade300,
                    )),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                review.text,
                style: AppTextStyles.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                review.formattedDate,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                ),
              ),
            ],
          ),
        )).toList(),
        
        // Google Maps에서 더 많은 리뷰 보기 안내
        if (widget.restaurant.googlePlaces!.userRatingsTotal > 5) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '더 많은 리뷰는 Google Maps에서 확인하세요',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }


  // 가게이름 + 카테고리 (한 줄)
  Widget _buildRestaurantName() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          widget.restaurant.name,
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.restaurant.shortCategory.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            widget.restaurant.shortCategory,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  // 압축된 평점 정보 (한 줄)
  Widget _buildCompactRatingInfo() {
    final googlePlaces = widget.restaurant.googlePlaces;
    final youtubeStats = widget.restaurant.youtubeStats;
    final naverBlog = widget.restaurant.naverBlog;
    
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Google 평점
        if (googlePlaces?.rating != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.asset(
              'assets/images/map_icons/google_app.jpg',
              width: 16,
              height: 16,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Google',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: 2),
          Text(
            googlePlaces!.rating!.toStringAsFixed(1),
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (googlePlaces.userRatingsTotal > 0) ...[
            Text(
              ' · 리뷰 ${googlePlaces.userRatingsTotal}개',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
          ],
        ],
        
        // YouTube 언급수
        if (youtubeStats != null) ...[
          if (googlePlaces?.rating != null) 
            Text(
              ' · ',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
          Icon(
            Icons.play_circle_filled,
            size: 16,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '${youtubeStats.mentionCount}회',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
        ],
        
        // 네이버 블로그 개수
        if (naverBlog != null) ...[
          if (googlePlaces?.rating != null || youtubeStats != null) 
            Text(
              ' · ',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.asset(
              'assets/images/map_icons/naver_blog.png',
              width: 16,
              height: 16,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Blog ${naverBlog.totalCount}회',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  // 사진 갤러리 (높이 200px)
  Widget _buildPhotoGallery() {
    // Google Places 사진들이 있으면 갤러리로 표시
    if (widget.restaurant.googlePlaces?.photos.isNotEmpty == true) {
      final photos = widget.restaurant.googlePlaces!.photos;
      return Container(
        height: 200,
        child: _buildImageGalleryCompact(photos),
      );
    }
    
    // 기존 이미지URL
    if (widget.restaurant.imageUrl != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.restaurant.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
          ),
        ),
      );
    }
    
    return _buildPhotoPlaceholder();
  }

  Widget _buildImageGalleryCompact(List<String> photos) {
    if (photos.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          photos.first,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width - 32; // 양쪽 padding 16씩 제외
    final photoWidth = screenWidth * 0.65;
    
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is ScrollUpdateNotification) {
              final scrollOffset = notification.metrics.pixels;
              final itemWidth = photoWidth + 8; // width + margin
              final newIndex = (scrollOffset / itemWidth).round().clamp(0, photos.length - 1);
              
              if (newIndex != _currentPhotoIndex) {
                setState(() {
                  _currentPhotoIndex = newIndex;
                });
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: photos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              
              return Container(
                width: photoWidth,
                height: 200,
                margin: EdgeInsets.only(
                  left: index == 0 ? 0 : 8,
                  right: index == photos.length - 1 ? 0 : 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
                  ),
                ),
              );
            }).toList(),
            ),
          ),
        ),
        // 페이지 인디케이터
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPhotoIndex + 1}/${photos.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: AppDesignTokens.onSurfaceVariant,
        ),
      ),
    );
  }

  // 주소 + 바로가기 버튼들
  Widget _buildAddressWithNavigation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주소
        Row(
          children: [
            Icon(
              Icons.location_on,
              size: 20,
              color: AppDesignTokens.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.restaurant.address,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // 바로가기 버튼들
        Row(
          children: [
            // 구글맵 버튼
            InkWell(
              onTap: () => _openGoogleMap(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4285F4).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        'assets/images/map_icons/google_maps.jpg',
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '구글맵',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF4285F4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 카카오맵 버튼
            InkWell(
              onTap: () => _openKakaoMap(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEB00).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFEB00).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        'assets/images/map_icons/kakao_map.jpg',
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '카카오맵',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFFCD9F00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 네이버맵 버튼
            InkWell(
              onTap: () => _openNaverMap(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF03C75A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF03C75A).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        'assets/images/map_icons/naver_map.webp',
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '네이버맵',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF00A040),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 영업시간 섹션
  Widget _buildOpeningHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '영업정보',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 전화번호
        if (widget.restaurant.googlePlaces?.phoneNumber != null) ...[
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.restaurant.googlePlaces!.phoneNumber!,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        
        // 간소화된 영업시간 표시
        if (widget.restaurant.googlePlaces?.regularOpeningHours != null)
          _buildSimpleOpeningHours(widget.restaurant.googlePlaces!.regularOpeningHours!),
      ],
    );
  }

  Widget _buildSimpleOpeningHours(Map<String, dynamic> regularOpeningHours) {
    try {
      final weekdayDescriptions = regularOpeningHours['weekdayDescriptions'] as List?;
      
      if (weekdayDescriptions == null || weekdayDescriptions.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '영업시간',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...weekdayDescriptions.take(7).map((description) {
            final descText = description.toString();
            final parts = descText.split(': ');
            final dayName = parts.isNotEmpty ? parts[0] : '';
            final hours = parts.length > 1 ? parts[1] : '정보 없음';
            
            final today = DateTime.now().weekday;
            final dayIndex = _getDayIndex(dayName);
            final isToday = dayIndex == today;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      dayName.substring(0, 1),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                        color: isToday ? AppDesignTokens.primary : AppDesignTokens.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hours,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                        color: isToday ? AppDesignTokens.primary : AppDesignTokens.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDetailedOpeningHours(Map<String, dynamic> regularOpeningHours) {
    try {
      // Google Places API의 regularOpeningHours 구조 파싱
      final weekdayDescriptions = regularOpeningHours['weekdayDescriptions'] as List?;
      
      if (weekdayDescriptions == null || weekdayDescriptions.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '영업시간',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppDesignTokens.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppDesignTokens.primary.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: weekdayDescriptions.take(7).map((description) {
                final descText = description.toString();
                
                // 요일과 시간 분리
                final parts = descText.split(': ');
                final dayName = parts.isNotEmpty ? parts[0] : '';
                final hours = parts.length > 1 ? parts[1] : '정보 없음';
                
                // 오늘 요일 확인
                final today = DateTime.now().weekday;
                final dayIndex = _getDayIndex(dayName);
                final isToday = dayIndex == today;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          _getShortDayName(dayName),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday 
                                ? AppDesignTokens.primary 
                                : AppDesignTokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hours,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                            color: isToday 
                                ? AppDesignTokens.primary 
                                : AppDesignTokens.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    } catch (e) {
      // 파싱 오류 시 기본 메시지 표시
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '영업시간 정보를 불러올 수 없습니다',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppDesignTokens.onSurfaceVariant,
          ),
        ),
      );
    }
  }

  String _getShortDayName(String fullDayName) {
    final dayMap = {
      'Monday': '월',
      'Tuesday': '화',
      'Wednesday': '수',
      'Thursday': '목',
      'Friday': '금',
      'Saturday': '토',
      'Sunday': '일',
      '월요일': '월',
      '화요일': '화',
      '수요일': '수',
      '목요일': '목',
      '금요일': '금',
      '토요일': '토',
      '일요일': '일',
    };
    
    return dayMap[fullDayName] ?? fullDayName.substring(0, 1);
  }

  int _getDayIndex(String dayName) {
    final dayIndexMap = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
      '월요일': 1,
      '화요일': 2,
      '수요일': 3,
      '목요일': 4,
      '금요일': 5,
      '토요일': 6,
      '일요일': 7,
    };
    
    return dayIndexMap[dayName] ?? 0;
  }

  void _openKakaoMap() async {
    final url = widget.restaurant.url ?? 
        'https://map.kakao.com/link/map/${widget.restaurant.name},${widget.restaurant.latitude},${widget.restaurant.longitude}';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // 에러 처리
    }
  }

  void _openGoogleMap() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.restaurant.name)}&query_place_id=${widget.restaurant.googlePlaces?.placeId ?? ""}';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // 에러 처리
    }
  }

  void _openNaverMap() async {
    final url = 'https://map.naver.com/v5/search/${Uri.encodeComponent(widget.restaurant.name)}?c=${widget.restaurant.longitude},${widget.restaurant.latitude},15,0,0,0,dh';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // 에러 처리
    }
  }

  // 특징 태그 (간소화된 버전)
  Widget _buildFeatureTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.restaurant.featureTags!.map((tag) => 
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppDesignTokens.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            tag,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppDesignTokens.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
      ).toList(),
    );
  }
  
  // 네이버 블로그 섹션
  Widget _buildNaverBlogSection() {
    final naverBlog = widget.restaurant.naverBlog!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.asset(
                'assets/images/map_icons/naver_blog.png',
                width: 20,
                height: 20,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '네이버 블로그',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '총 ${naverBlog.totalCount}개',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        ...naverBlog.posts.map((post) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _openBlogPost(post.link),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppDesignTokens.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    post.description,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppDesignTokens.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.bloggerName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppDesignTokens.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppDesignTokens.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatBlogDate(post.postDate),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppDesignTokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ],
    );
  }
  
  void _openBlogPost(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // 에러 처리
    }
  }
  
  String _formatBlogDate(String dateString) {
    try {
      // 네이버 블로그 날짜 형식: YYYYMMDD
      if (dateString.length == 8) {
        final year = dateString.substring(0, 4);
        final month = dateString.substring(4, 6);
        final day = dateString.substring(6, 8);
        return '$year.$month.$day';
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }
}