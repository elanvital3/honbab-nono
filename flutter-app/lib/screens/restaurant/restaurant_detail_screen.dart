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
      body: CustomScrollView(
        slivers: [
          // 대형 이미지와 앱바
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppDesignTokens.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroImage(),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border, 
                    color: _isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _isLoading ? null : _toggleFavorite,
                ),
              ),
            ],
          ),
          
          // 메인 컨텐츠
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목과 기본 정보
                  _buildHeaderSection(),
                  
                  const SizedBox(height: 24),
                  
                  // 통계 정보
                  _buildStatsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // 추가 정보 섹션
                  if (widget.restaurant.googlePlaces?.priceLevel != null || 
                      widget.restaurant.featureTags?.isNotEmpty == true ||
                      widget.restaurant.trendScore != null) ...[
                    _buildAdditionalInfoSection(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Google 리뷰 섹션
                  if (widget.restaurant.googlePlaces?.reviews.isNotEmpty == true) ...[
                    _buildReviewsSection(),
                    const SizedBox(height: 24),
                  ],
                  
                  // 위치 정보
                  _buildLocationSection(),
                  
                  const SizedBox(height: 100), // 하단 여백
                ],
              ),
            ),
          ),
        ],
      ),
      
      // 하단 액션 버튼들
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesignTokens.surface,
          border: Border(
            top: BorderSide(
              color: AppDesignTokens.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openKakaoMap(),
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFFFEB00), // 카카오 노란색
                    size: 16,
                  ),
                ),
                label: const Text('카카오맵'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00), // 카카오 브랜드 컬러
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openNaverMap(),
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Color(0xFF03C75A), // 네이버 초록색
                    size: 16,
                  ),
                ),
                label: const Text('네이버지도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03C75A), // 네이버 브랜드 컬러
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    // Google Places 사진들이 있으면 갤러리로 표시
    if (widget.restaurant.googlePlaces?.photos.isNotEmpty == true) {
      final photos = widget.restaurant.googlePlaces!.photos;
      if (photos.length > 1) {
        return _buildImageGallery(photos);
      } else {
        return Image.network(
          photos.first,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        );
      }
    }
    
    // 기존 이미지URL
    if (widget.restaurant.imageUrl != null) {
      return Image.network(
        widget.restaurant.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }
    
    return _buildPlaceholderImage();
  }

  Widget _buildImageGallery(List<String> photos) {
    final PageController pageController = PageController(viewportFraction: 0.65);
    
    return Stack(
      children: [
        // 사진 높이를 70%로 줄임
        Container(
          height: 210, // 300 * 0.7 = 210
          child: PageView.builder(
            controller: pageController,
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photos[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                  ),
                ),
              );
            },
          ),
        ),
        // 페이지 인디케이터
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${photos.length}장',
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
  
  Widget _buildFallbackImage() {
    if (widget.restaurant.imageUrl != null) {
      return Image.network(
        widget.restaurant.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }
    return _buildPlaceholderImage();
  }
  
  Widget _buildPlaceholderImage() {
    return Container(
      color: AppDesignTokens.surfaceContainer,
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 80,
          color: AppDesignTokens.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.restaurant.name,
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          widget.restaurant.address,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppDesignTokens.onSurfaceVariant,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 카테고리 태그
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppDesignTokens.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.restaurant.shortCategory,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '맛집 정보',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            // YouTube 정보
            if (widget.restaurant.youtubeStats != null)
              Expanded(
                child: _buildStatCard(
                  icon: Icons.play_circle_filled,
                  iconColor: Colors.red,
                  title: 'YouTube 언급',
                  value: '${widget.restaurant.youtubeStats!.mentionCount}회',
                  subtitle: widget.restaurant.youtubeStats!.channels.isNotEmpty 
                      ? widget.restaurant.youtubeStats!.channels.first
                      : null,
                ),
              ),
            
            if (widget.restaurant.youtubeStats != null && widget.restaurant.googlePlaces?.rating != null)
              const SizedBox(width: 12),
            
            // Google 평점
            if (widget.restaurant.googlePlaces?.rating != null)
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  iconColor: Colors.orange,
                  title: 'Google 평점',
                  value: '${widget.restaurant.googlePlaces!.rating!.toStringAsFixed(1)}/5',
                  subtitle: widget.restaurant.googlePlaces!.userRatingsTotal > 0 
                      ? '${widget.restaurant.googlePlaces!.userRatingsTotal}개 리뷰'
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
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
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '추가 정보',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 가격대 정보
        if (widget.restaurant.googlePlaces?.priceLevel != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  '가격대',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppDesignTokens.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _getPriceLevelText(widget.restaurant.googlePlaces!.priceLevel!),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        
        // 특징 태그
        if (widget.restaurant.featureTags?.isNotEmpty == true)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                    const Icon(Icons.local_offer, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '특징',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppDesignTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.restaurant.featureTags!.map((tag) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
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
                ),
              ],
            ),
          ),
        
        // 트렌드 정보
        if (widget.restaurant.trendScore != null)
          Container(
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
                    const Icon(Icons.trending_up, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '트렌드 점수',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppDesignTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${widget.restaurant.trendScore!.hotness}',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            '핫함 지수',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppDesignTokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${widget.restaurant.trendScore!.consistency}',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            '일관성',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppDesignTokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            widget.restaurant.trendScore!.isRising 
                                ? Icons.trending_up 
                                : Icons.trending_down,
                            color: widget.restaurant.trendScore!.isRising 
                                ? Colors.green 
                                : Colors.red,
                          ),
                          Text(
                            widget.restaurant.trendScore!.isRising ? '상승중' : '하락중',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppDesignTokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getPriceLevelText(int priceLevel) {
    switch (priceLevel) {
      case 1:
        return '저렴함 (\$)';
      case 2:
        return '보통 (\$\$)';
      case 3:
        return '비쌈 (\$\$\$)';
      case 4:
        return '매우 비쌈 (\$\$\$\$)';
      default:
        return '정보 없음';
    }
  }

  Widget _buildReviewsSection() {
    final reviews = widget.restaurant.googlePlaces!.reviews;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Google 리뷰',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${reviews.length}개 표시',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppDesignTokens.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.restaurant.googlePlaces!.userRatingsTotal > 5) ...[
                  const SizedBox(height: 4),
                  Text(
                    '전체 ${widget.restaurant.googlePlaces!.userRatingsTotal}개',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppDesignTokens.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
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

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '위치 정보',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
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
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.restaurant.address,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
              
              if (widget.restaurant.googlePlaces?.phoneNumber != null) ...[
                const SizedBox(height: 12),
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
              ],
              
              if (widget.restaurant.googlePlaces?.isOpen != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: widget.restaurant.googlePlaces!.isOpen! 
                          ? Colors.green 
                          : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.restaurant.googlePlaces!.isOpen! ? '영업중' : '마감',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: widget.restaurant.googlePlaces!.isOpen! 
                            ? Colors.green 
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
              // 상세 영업시간 표시
              if (widget.restaurant.googlePlaces?.regularOpeningHours != null) ...[
                const SizedBox(height: 16),
                _buildDetailedOpeningHours(widget.restaurant.googlePlaces!.regularOpeningHours!),
              ],
            ],
          ),
        ),
      ],
    );
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

  void _openNaverMap() async {
    final url = 'https://map.naver.com/v5/search/${Uri.encodeComponent(widget.restaurant.name)}?c=${widget.restaurant.longitude},${widget.restaurant.latitude},15,0,0,0,dh';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // 에러 처리
    }
  }
}