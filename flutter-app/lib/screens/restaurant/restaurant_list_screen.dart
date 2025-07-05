import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../models/restaurant.dart';
import '../../services/restaurant_service.dart';
import 'restaurant_detail_screen.dart';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  // 현재 선택된 지역 인덱스
  int _currentRegionIndex = 0;
  
  // 지역별 맛집 데이터
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;
  final Map<String, bool> _favoriteStatus = {};
  
  // 정렬 옵션
  String _sortOption = 'rating'; // 기본값: 평점순
  
  final List<Map<String, dynamic>> regions = [
    {
      'name': '제주도', 
      'emoji': '🏝️',
      'subtitle': '제주시 · 서귀포',
      'imagePath': 'assets/images/regions/jeju.jpg',
    },
    {
      'name': '서울', 
      'emoji': '🗼',
      'subtitle': '강남 · 홍대 · 명동 · 이태원',
      'imagePath': 'assets/images/regions/seoul.jpg',
    },
    {
      'name': '부산', 
      'emoji': '🌊',
      'subtitle': '해운대 · 서면 · 광안리',
      'imagePath': 'assets/images/regions/busan.webp',
    },
    {
      'name': '경주', 
      'emoji': '🏯',
      'subtitle': '불국사 · 첨성대 주변',
      'imagePath': 'assets/images/regions/gyeongju.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    // 첫 번째 지역(제주도) 데이터 로드
    _loadRegionData();
  }
  
  // 현재 선택된 지역 가져오기
  Map<String, dynamic> get currentRegion => regions[_currentRegionIndex];
  
  // 이전 지역으로 이동
  void _previousRegion() {
    setState(() {
      _currentRegionIndex = (_currentRegionIndex - 1 + regions.length) % regions.length;
    });
    _loadRegionData();
  }
  
  // 다음 지역으로 이동
  void _nextRegion() {
    setState(() {
      _currentRegionIndex = (_currentRegionIndex + 1) % regions.length;
    });
    _loadRegionData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            // 지역 배너 헤더 with 좌우 버튼
            _buildRegionBanner(),
            
            // 정렬 옵션
            _buildSortingOptions(),
            
            // 맛집 리스트
            Expanded(
              child: _buildRestaurantList(),
            ),
          ],
        ),
      ),
    );
  }

  // 지역 배너 with 좌우 버튼
  Widget _buildRegionBanner() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // 배경 배너
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // 배경 이미지
                  Positioned.fill(
                    child: Image.asset(
                      currentRegion['imagePath'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppDesignTokens.primary.withOpacity(0.7),
                                AppDesignTokens.primary,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // 반투명 오버레이
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // 콘텐츠
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // 좌측 화살표
                        IconButton(
                          onPressed: _previousRegion,
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.3),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        
                        // 중앙 지역 정보
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentRegion['name'],
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 3,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentRegion['subtitle'],
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 우측 화살표
                        IconButton(
                          onPressed: _nextRegion,
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.3),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 정렬 옵션
  Widget _buildSortingOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        border: Border(
          bottom: BorderSide(
            color: AppDesignTokens.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '정렬:',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sortOption,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'hybrid', child: Text('하이브리드 추천순')),
              DropdownMenuItem(value: 'rating', child: Text('평점순')),
              DropdownMenuItem(value: 'youtube', child: Text('YouTube 언급순')),
              DropdownMenuItem(value: 'reviews', child: Text('리뷰 많은순')),
              DropdownMenuItem(value: 'source', child: Text('소스별')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sortOption = value;
                });
                _loadRegionData(forceRefresh: true);
              }
            },
          ),
        ],
      ),
    );
  }
  
  // 맛집 리스트
  Widget _buildRestaurantList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_restaurants.isEmpty) {
      return _buildNoRestaurantsView();
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadRegionData(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _restaurants[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildEnhancedRestaurantCard(
              restaurant: restaurant,
              isFavorite: _favoriteStatus[restaurant.id] ?? false,
              onFavoriteToggle: () => _toggleFavorite(restaurant.id),
            ),
          );
        },
      ),
    );
  }

  // 지역 데이터 로드 메서드
  Future<void> _loadRegionData({bool forceRefresh = false}) async {
    final regionName = currentRegion['name'];
    
    setState(() {
      _isLoading = true;
    });

    try {
      final restaurants = await RestaurantService.getRestaurantsByRegion(
        region: regionName,
        limit: 30,
      );

      if (mounted) {
        // 정렬 적용
        final sortedRestaurants = _sortRestaurants(restaurants);
        
        setState(() {
          _restaurants = sortedRestaurants;
          _isLoading = false;
        });

        // 즐겨찾기 상태 로드
        await _loadFavoriteStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 맛집 정렬
  List<Restaurant> _sortRestaurants(List<Restaurant> restaurants) {
    final sortedList = List<Restaurant>.from(restaurants);
    
    switch (_sortOption) {
      case 'rating':
        sortedList.sort((a, b) {
          final aRating = a.googlePlaces?.rating ?? 0.0;
          final bRating = b.googlePlaces?.rating ?? 0.0;
          return bRating.compareTo(aRating); // 높은 평점 우선
        });
        break;
        
      case 'youtube':
        sortedList.sort((a, b) {
          final aMentions = a.youtubeStats?.mentionCount ?? 0;
          final bMentions = b.youtubeStats?.mentionCount ?? 0;
          return bMentions.compareTo(aMentions); // 많은 언급 우선
        });
        break;
        
      case 'reviews':
        sortedList.sort((a, b) {
          final aReviews = a.googlePlaces?.userRatingsTotal ?? 0;
          final bReviews = b.googlePlaces?.userRatingsTotal ?? 0;
          return bReviews.compareTo(aReviews); // 많은 리뷰 우선
        });
        break;
        
      case 'default':
      default:
        // 기본 정렬: YouTube 언급수와 Google 평점 종합
        sortedList.sort((a, b) {
          final aScore = (a.youtubeStats?.mentionCount ?? 0) * 0.3 + 
                        (a.googlePlaces?.rating ?? 0.0) * 2.0;
          final bScore = (b.youtubeStats?.mentionCount ?? 0) * 0.3 + 
                        (b.googlePlaces?.rating ?? 0.0) * 2.0;
          return bScore.compareTo(aScore);
        });
        break;
    }
    
    return sortedList;
  }

  // 즐겨찾기 상태 로드
  Future<void> _loadFavoriteStatus() async {
    _favoriteStatus.clear();

    for (final restaurant in _restaurants) {
      try {
        final isFav = await RestaurantService.isFavorite(restaurant.id);
        if (mounted) {
          setState(() {
            _favoriteStatus[restaurant.id] = isFav;
          });
        }
      } catch (e) {
        _favoriteStatus[restaurant.id] = false;
      }
    }
  }

  // 즐겨찾기 토글
  Future<void> _toggleFavorite(String restaurantId) async {
    try {
      final success = await RestaurantService.toggleFavorite(restaurantId);
      if (success && mounted) {
        setState(() {
          final currentStatus = _favoriteStatus[restaurantId] ?? false;
          _favoriteStatus[restaurantId] = !currentStatus;
        });
        
        final isNowFavorite = _favoriteStatus[restaurantId]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowFavorite ? '즐겨찾기에 추가했습니다' : '즐겨찾기에서 제거했습니다'),
            backgroundColor: AppDesignTokens.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('즐겨찾기 처리에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 맛집 없음 뷰
  Widget _buildNoRestaurantsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 64,
              color: AppDesignTokens.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '${currentRegion['name']} 맛집 준비 중',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '곧 다양한 맛집 정보를\n만나보실 수 있습니다!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 향상된 맛집 카드
  Widget _buildEnhancedRestaurantCard({
    required Restaurant restaurant,
    required bool isFavorite,
    required VoidCallback onFavoriteToggle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
        height: 140, // 140으로 더 줄여서 오버플로우 해결
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // 이미지 (90x90으로 줄임)
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppDesignTokens.surfaceContainer,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildRestaurantImage(restaurant),
              ),
            ),
            
            const SizedBox(width: 10),
            
            // 확장된 정보 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 제목과 즐겨찾기
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onFavoriteToggle,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : AppDesignTokens.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  
                  // 유튜브 통계 정보
                  if (restaurant.youtubeStats != null) ...[
                    const SizedBox(height: 2),
                    _buildYoutubeInfo(restaurant.youtubeStats!),
                  ],
                  
                  // Google Places 평점 정보
                  if (restaurant.googlePlaces != null) ...[
                    const SizedBox(height: 2),
                    _buildGooglePlacesInfo(restaurant.googlePlaces!),
                  ],
                  
                  const SizedBox(height: 4),
                  
                  // 태그들
                  if (restaurant.featureTags != null && restaurant.featureTags!.isNotEmpty) ...[
                    _buildTagsRow(restaurant.featureTags!),
                    const SizedBox(height: 4),
                  ],
                  
                  const Spacer(),
                  
                  // 하단: 주소와 지도 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppDesignTokens.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildMapButtons(restaurant),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // 맛집 이미지 (Google Places 우선)
  Widget _buildRestaurantImage(Restaurant restaurant) {
    // 1순위: Google Places 사진
    if (restaurant.googlePlaces?.photos.isNotEmpty == true) {
      return Image.network(
        restaurant.googlePlaces!.photos.first,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(restaurant),
      );
    }
    
    // 2순위: 기존 imageUrl
    if (restaurant.imageUrl != null) {
      return Image.network(
        restaurant.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    }
    
    // 3순위: 플레이스홀더
    return _buildImagePlaceholder();
  }
  
  // 대체 이미지 (Google 사진 로드 실패 시)
  Widget _buildFallbackImage(Restaurant restaurant) {
    if (restaurant.imageUrl != null) {
      return Image.network(
        restaurant.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  // 이미지 플레이스홀더
  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.restaurant,
        size: 48,
        color: AppDesignTokens.onSurfaceVariant,
      ),
    );
  }

  // 유튜브 정보
  Widget _buildYoutubeInfo(YoutubeStats stats) {
    return Row(
      children: [
        Text(
          '📺 ${stats.mentionCount}회',
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        // 대표 채널
        if (stats.representativeVideo != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stats.representativeVideo!.channelName,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  // Google Places 정보
  Widget _buildGooglePlacesInfo(GooglePlacesData googlePlaces) {
    return Row(
      children: [
        // Google 평점
        if (googlePlaces.rating != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 2),
                Text(
                  '${googlePlaces.rating!.toStringAsFixed(1)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (googlePlaces.userRatingsTotal > 0) ...[
                  Text(
                    ' (${googlePlaces.userRatingsTotal})',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        
        // 영업 상태 (있는 경우)
        if (googlePlaces.isOpen != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: googlePlaces.isOpen! 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              googlePlaces.isOpen! ? '영업중' : '마감',
              style: AppTextStyles.bodySmall.copyWith(
                color: googlePlaces.isOpen! 
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  // 태그 행
  Widget _buildTagsRow(List<String> tags) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.take(3).map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppDesignTokens.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          tag,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppDesignTokens.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }

  // 지도 버튼들
  Widget _buildMapButtons(Restaurant restaurant) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 카카오맵 버튼
        InkWell(
          onTap: () => _openKakaoMap(restaurant),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppDesignTokens.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.map,
              size: 20,
              color: AppDesignTokens.primary,
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 네이버지도 버튼
        InkWell(
          onTap: () => _openNaverMap(restaurant),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.navigation,
              size: 20,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // 카카오맵 열기
  void _openKakaoMap(Restaurant restaurant) async {
    final url = restaurant.url ?? 
        'https://map.kakao.com/link/map/${restaurant.name},${restaurant.latitude},${restaurant.longitude}';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오맵을 열 수 없습니다')),
        );
      }
    }
  }

  // 네이버지도 열기
  void _openNaverMap(Restaurant restaurant) async {
    final url = 'https://map.naver.com/v5/search/${Uri.encodeComponent(restaurant.name)}?c=${restaurant.longitude},${restaurant.latitude},15,0,0,0,dh';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네이버지도를 열 수 없습니다')),
        );
      }
    }
  }
}
