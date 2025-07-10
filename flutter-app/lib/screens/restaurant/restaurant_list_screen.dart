import 'package:flutter/material.dart';
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
  
  // 무한 스크롤 관련 변수들
  List<Restaurant> _restaurants = [];
  List<Restaurant> _remainingRestaurants = []; // 🔥 남은 데이터 저장
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _favoriteStatus = {};
  
  // 정렬 옵션
  String _sortOption = 'default'; // 기본값: 추천순
  
  // 서브 지역 필터
  String _selectedSubRegion = '전체';
  
  // 지역별 서브 지역 매핑 (관광지 인기순)
  final Map<String, List<String>> subRegions = {
    '제주도': ['전체', '제주시', '서귀포시'],
    '서울': ['전체', '홍대', '강남', '명동', '이태원', '인사동', '동대문'],
    '부산': ['전체', '해운대', '서면', '광안리', '남포동', '송정', '기장'],
  };
  
  final List<Map<String, dynamic>> regions = [
    {
      'name': '제주도', 
      'emoji': '🏝️',
      'subtitle': '제주시 · 서귀포시',
      'imagePath': 'assets/images/regions/jeju.jpg',
    },
    {
      'name': '서울', 
      'emoji': '🗼',
      'subtitle': '홍대 · 강남 · 명동 · 이태원',
      'imagePath': 'assets/images/regions/seoul.jpg',
    },
    {
      'name': '부산', 
      'emoji': '🌊',
      'subtitle': '해운대 · 서면 · 광안리 · 남포동',
      'imagePath': 'assets/images/regions/busan.webp',
    },
  ];

  @override
  void initState() {
    super.initState();
    // 스크롤 리스너 추가
    _scrollController.addListener(_onScroll);
    // 첫 번째 지역(제주도) 데이터 로드
    _loadRegionData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 이벤트 핸들러
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // 바닥에서 200px 전에 더 로드
      _loadMoreRestaurants();
    }
  }
  
  // 현재 선택된 지역 가져오기
  Map<String, dynamic> get currentRegion => regions[_currentRegionIndex];
  
  // 이전 지역으로 이동
  void _previousRegion() {
    setState(() {
      _currentRegionIndex = (_currentRegionIndex - 1 + regions.length) % regions.length;
      _selectedSubRegion = '전체'; // 지역 변경 시 서브 지역 초기화
      _resetPagination(); // 페이지네이션 상태 초기화
    });
    _loadRegionData();
  }
  
  // 다음 지역으로 이동
  void _nextRegion() {
    setState(() {
      _currentRegionIndex = (_currentRegionIndex + 1) % regions.length;
      _selectedSubRegion = '전체'; // 지역 변경 시 서브 지역 초기화
      _resetPagination(); // 페이지네이션 상태 초기화
    });
    _loadRegionData();
  }

  // 페이지네이션 상태 초기화
  void _resetPagination() {
    _restaurants.clear();
    _remainingRestaurants.clear(); // 🔥 남은 데이터도 초기화
    _hasMore = true;
    _isLoadingMore = false;
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
      height: 108,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
  
  // 필터 및 정렬 옵션
  Widget _buildSortingOptions() {
    final currentSubRegions = subRegions[currentRegion['name']] ?? ['전체'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        border: Border(
          bottom: BorderSide(
            color: AppDesignTokens.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // 상단: 지역 필터 칩들 (왼쪽 정렬)
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: currentSubRegions.map((subRegion) {
                final isSelected = _selectedSubRegion == subRegion;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSubRegion = subRegion;
                      });
                      _loadRegionData(forceRefresh: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.black 
                            : AppDesignTokens.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        subRegion,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected 
                              ? Colors.white 
                              : AppDesignTokens.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // 하단: 정렬 드롭다운 (오른쪽 정렬)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
                isDense: true,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppDesignTokens.onSurface,
                ),
                iconSize: 16,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                ),
                selectedItemBuilder: (BuildContext context) {
                  return ['추천순', '평점순'].map((String value) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _sortOption == 'default' ? '추천순' : '평점순',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppDesignTokens.onSurface,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('추천순')),
                  DropdownMenuItem(value: 'rating', child: Text('평점순')),
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
      child: ListView.separated(
        controller: _scrollController, // 🔥 스크롤 컨트롤러 추가
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _restaurants.length + (_hasMore ? 1 : 0), // 🔥 로딩 인디케이터 위한 +1
        separatorBuilder: (context, index) {
          // 마지막 아이템(로딩 인디케이터)에는 구분선 없음
          if (index >= _restaurants.length - 1) {
            return const SizedBox.shrink();
          }
          return Divider(
            height: 1,
            thickness: 1,
            color: AppDesignTokens.outline.withOpacity(0.1),
            indent: 16,
            endIndent: 16,
          );
        },
        itemBuilder: (context, index) {
          // 🔥 로딩 인디케이터 표시
          if (index >= _restaurants.length) {
            return _buildLoadingIndicator();
          }
          
          final restaurant = _restaurants[index];
          return _buildEnhancedRestaurantCard(
            restaurant: restaurant,
            isFavorite: _favoriteStatus[restaurant.id] ?? false,
            onFavoriteToggle: () => _toggleFavorite(restaurant.id),
          );
        },
      ),
    );
  }

  // 하단 로딩 인디케이터
  Widget _buildLoadingIndicator() {
    if (!_isLoadingMore) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppDesignTokens.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '더 많은 맛집을 불러오는 중...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 지역 데이터 로드 메서드 (기존 방식 + 무한 스크롤 준비)
  Future<void> _loadRegionData({bool forceRefresh = false}) async {
    final regionName = currentRegion['name'];
    
    if (forceRefresh) {
      _resetPagination();
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 🔥 기존 방식 사용 (검증된 로직)
      final restaurants = await RestaurantService.getRestaurantsByRegion(
        region: regionName,
        limit: 100, // 일단 많이 가져와서 클라이언트에서 페이징
      );

      if (mounted) {
        // 서브 지역 필터링 적용
        final filteredRestaurants = _filterBySubRegion(restaurants);
        
        // 정렬 적용
        final sortedRestaurants = _sortRestaurants(filteredRestaurants);
        
        // 🔥 클라이언트 사이드 페이징 (첫 20개만)
        final initialRestaurants = sortedRestaurants.take(20).toList();
        final remainingRestaurants = sortedRestaurants.skip(20).toList();
        
        setState(() {
          _restaurants = initialRestaurants;
          _remainingRestaurants = remainingRestaurants; // 남은 데이터 저장
          _hasMore = remainingRestaurants.isNotEmpty;
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

  // 더 많은 식당 로드 (무한 스크롤) - 클라이언트 사이드 페이징
  Future<void> _loadMoreRestaurants() async {
    if (_isLoadingMore || !_hasMore || _remainingRestaurants.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // 남은 데이터에서 다음 페이지 가져오기 (20개씩)
      const pageSize = 20;
      final nextBatch = _remainingRestaurants.take(pageSize).toList();
      final remainingAfterBatch = _remainingRestaurants.skip(pageSize).toList();

      if (mounted) {
        setState(() {
          _restaurants.addAll(nextBatch);
          _remainingRestaurants = remainingAfterBatch;
          _hasMore = remainingAfterBatch.isNotEmpty;
          _isLoadingMore = false;
        });

        // 새로 로드된 식당들의 즐겨찾기 상태 로드
        await _loadFavoriteStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }


  // 서브 지역 필터링
  List<Restaurant> _filterBySubRegion(List<Restaurant> restaurants) {
    if (_selectedSubRegion == '전체') {
      return restaurants;
    }
    
    return restaurants.where((restaurant) {
      final address = restaurant.address.toLowerCase();
      final subRegion = _selectedSubRegion.toLowerCase();
      
      // 서브 지역명이 주소에 포함되어 있는지 확인
      if (subRegion.contains('제주시')) {
        return address.contains('제주시');
      } else if (subRegion.contains('서귀포')) {
        return address.contains('서귀포');
      } else if (subRegion.contains('강남')) {
        return address.contains('강남');
      } else if (subRegion.contains('홍대')) {
        return address.contains('홍대') || address.contains('마포');
      } else if (subRegion.contains('명동')) {
        return address.contains('명동') || address.contains('중구');
      } else if (subRegion.contains('이태원')) {
        return address.contains('이태원') || address.contains('용산');
      } else if (subRegion.contains('인사동')) {
        return address.contains('인사동') || address.contains('종로');
      } else if (subRegion.contains('동대문')) {
        return address.contains('동대문') || address.contains('중랑');
      } else if (subRegion.contains('해운대')) {
        return address.contains('해운대');
      } else if (subRegion.contains('서면')) {
        return address.contains('서면') || address.contains('부산진');
      } else if (subRegion.contains('광안리')) {
        return address.contains('광안리') || address.contains('수영');
      } else if (subRegion.contains('남포동')) {
        return address.contains('남포동') || address.contains('중구');
      } else if (subRegion.contains('송정')) {
        return address.contains('송정') || address.contains('해운대구');
      } else if (subRegion.contains('기장')) {
        return address.contains('기장');
      }
      
      return address.contains(subRegion);
    }).toList();
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
        
        
      case 'default':
      default:
        // 추천순: YouTube 언급 + Google 평점 + 리뷰 신뢰성 종합
        sortedList.sort((a, b) {
          // YouTube 화제성 점수 (0-6점)
          final aYoutubeScore = (a.youtubeStats?.mentionCount ?? 0) * 0.3;
          final bYoutubeScore = (b.youtubeStats?.mentionCount ?? 0) * 0.3;
          
          // Google 평점 기본 점수 (0-10점)  
          final aRating = a.googlePlaces?.rating ?? 0.0;
          final bRating = b.googlePlaces?.rating ?? 0.0;
          final aRatingScore = aRating * 2.0;
          final bRatingScore = bRating * 2.0;
          
          // 리뷰 개수 신뢰성 보너스 (0-2점)
          final aReviewCount = a.googlePlaces?.userRatingsTotal ?? 0;
          final bReviewCount = b.googlePlaces?.userRatingsTotal ?? 0;
          final aReviewBonus = _calculateReviewBonus(aReviewCount, aRating);
          final bReviewBonus = _calculateReviewBonus(bReviewCount, bRating);
          
          final aScore = aYoutubeScore + aRatingScore + aReviewBonus;
          final bScore = bYoutubeScore + bRatingScore + bReviewBonus;
          
          return bScore.compareTo(aScore);
        });
        break;
    }
    
    return sortedList;
  }

  // 리뷰 개수 기반 신뢰성 보너스 계산
  double _calculateReviewBonus(int reviewCount, double rating) {
    if (rating == 0) return 0.0; // 평점이 없으면 보너스 없음
    
    // 리뷰 개수별 신뢰성 가중치
    double reliabilityWeight;
    if (reviewCount >= 100) {
      reliabilityWeight = 1.0; // 매우 신뢰성 높음
    } else if (reviewCount >= 50) {
      reliabilityWeight = 0.8; // 신뢰성 높음
    } else if (reviewCount >= 20) {
      reliabilityWeight = 0.6; // 보통 신뢰성
    } else if (reviewCount >= 10) {
      reliabilityWeight = 0.4; // 낮은 신뢰성
    } else if (reviewCount >= 5) {
      reliabilityWeight = 0.2; // 매우 낮은 신뢰성
    } else {
      reliabilityWeight = 0.0; // 신뢰성 없음
    }
    
    // 높은 평점일수록 더 큰 보너스 (4.0 이상부터 보너스)
    final ratingBonus = rating >= 4.0 ? (rating - 4.0) : 0.0;
    
    return reliabilityWeight * ratingBonus * 2.0; // 최대 2점 보너스
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
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 크기 조정
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppDesignTokens.surfaceContainer,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildRestaurantImage(restaurant),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 확장된 정보 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 맛집 이름 + 즐겨찾기 버튼 (버튼 상단 고정)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : AppDesignTokens.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // 2. 구글 평점 · 유튜브 언급 (한 줄) - 간격 미세 조정
                  if (restaurant.googlePlaces?.rating != null || restaurant.youtubeStats != null) ...[
                    const SizedBox(height: 1),
                    _buildRatingAndYoutubeInfo(restaurant),
                    const SizedBox(height: 4),
                  ] else ...[
                    const SizedBox(height: 4),
                  ],
                  
                  // 3. 주소
                  Text(
                    restaurant.address,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppDesignTokens.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 5),
                  
                  // 4. 태그 (최대 3개)
                  if (restaurant.featureTags != null && restaurant.featureTags!.isNotEmpty) ...[
                    _buildTagsRow(restaurant.featureTags!),
                  ],
                ],
              ),
            ),
          ],
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

  // 통합된 평점 및 유튜브 정보 (한 줄)
  Widget _buildRatingAndYoutubeInfo(Restaurant restaurant) {
    final googlePlaces = restaurant.googlePlaces;
    final youtubeStats = restaurant.youtubeStats;
    final naverBlog = restaurant.naverBlog;
    
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Google 평점
        if (googlePlaces?.rating != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.asset(
              'assets/images/map_icons/google_app.jpg',
              width: 12,
              height: 12,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            (googlePlaces?.userRatingsTotal ?? 0) > 0 
                ? 'Google ⭐ ${googlePlaces!.rating!.toStringAsFixed(1)} (${googlePlaces!.userRatingsTotal}개)'
                : 'Google ⭐ ${googlePlaces!.rating!.toStringAsFixed(1)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF4285F4),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
        
        // 구분자 (Google과 YouTube 사이)
        if (googlePlaces?.rating != null && youtubeStats != null) ...[
          Text(
            ' · ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
        
        // YouTube 언급
        if (youtubeStats != null) ...[
          Icon(
            Icons.play_circle_filled,
            size: 12,
            color: Colors.red,
          ),
          const SizedBox(width: 3),
          Text(
            'YouTube ${youtubeStats.mentionCount}회',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
        
      ],
    );
  }

  // Google Places 정보
  Widget _buildGooglePlacesInfo(GooglePlacesData googlePlaces) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Google 평점
        if (googlePlaces.rating != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.asset(
                    'assets/images/map_icons/google_app.jpg',
                    width: 12,
                    height: 12,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.orange,
                ),
                const SizedBox(width: 2),
                Text(
                  '${googlePlaces.rating!.toStringAsFixed(1)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF4285F4),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (googlePlaces.userRatingsTotal > 0) ...[
                  Text(
                    '(${googlePlaces.userRatingsTotal})',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF4285F4),
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
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
                fontSize: 10,
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


}
