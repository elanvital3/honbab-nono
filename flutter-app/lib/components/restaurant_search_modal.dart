import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/restaurant.dart';
import '../services/kakao_search_service.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import 'hierarchical_location_picker.dart';

class RestaurantSearchModal extends StatefulWidget {
  final Function(Restaurant) onRestaurantSelected;

  const RestaurantSearchModal({
    super.key,
    required this.onRestaurantSelected,
  });

  @override
  State<RestaurantSearchModal> createState() => _RestaurantSearchModalState();
}

class _RestaurantSearchModalState extends State<RestaurantSearchModal> {
  final _searchController = TextEditingController();
  List<Restaurant> _searchResults = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _selectedLocation; // null = 현재 위치 사용
  String? _currentUserId;
  Set<String> _favoriteRestaurantIds = {}; // 즐겨찾기 식당 ID 목록

  @override
  void initState() {
    super.initState();
    // 즉시 UI 표시
    setState(() {
      _isInitialLoading = false;
    });
    // 백그라운드에서 위치 초기화
    _initializeLocation();
    // 사용자 정보 및 즐겨찾기 로드
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = AuthService.currentFirebaseUser;
      if (user != null) {
        _currentUserId = user.uid;
        final favoriteIds = await UserService.getUserFavoriteRestaurants(user.uid);
        if (mounted) {
          setState(() {
            _favoriteRestaurantIds = favoriteIds.toSet();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 데이터 로드 실패: $e');
      }
    }
  }

  Future<void> _initializeLocation() async {
    // 백그라운드에서 현재 위치 초기화 (UI 블로킹 없음)
    try {
      final currentLocation = await LocationService.getCurrentLocation();
      // 위치 확인만 하고 별도 처리 없음 (거리 계산은 검색 시에 수행)
    } catch (e) {
      // 위치 실패해도 검색은 가능하므로 무시
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _searchRestaurants(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await _performSearch(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Restaurant>> _performSearch(String query) async {
    // 한국 내 위치로 고정 (에뮬레이터는 해외 위치이므로)
    KakaoSearchService.setSelectedCity('서울시');
    
    // 실시간 카카오 API 검색 (서울 기준)
    final results = await KakaoSearchService.searchRestaurants(
      query: query.trim(),
      size: 15,
      nationwide: true, // 전국 검색 유지
    );
    
    return results;
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    if (_currentUserId == null) return;
    
    try {
      final isFavorite = _favoriteRestaurantIds.contains(restaurant.id);
      
      if (isFavorite) {
        // 즐겨찾기에서 제거
        await UserService.removeFavoriteRestaurant(_currentUserId!, restaurant.id);
        if (mounted) {
          setState(() {
            _favoriteRestaurantIds.remove(restaurant.id);
          });
        }
        
        // 사용자 피드백
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❤️ ${restaurant.name}을(를) 즐겨찾기에서 제거했어요'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 즐겨찾기에 추가
        await UserService.addFavoriteRestaurant(_currentUserId!, restaurant.id);
        if (mounted) {
          setState(() {
            _favoriteRestaurantIds.add(restaurant.id);
          });
        }
        
        // 사용자 피드백
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❤️ ${restaurant.name}을(를) 즐겨찾기에 추가했어요!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      if (kDebugMode) {
        print('🍽️ 즐겨찾기 ${isFavorite ? "제거" : "추가"}: ${restaurant.name} (${restaurant.id})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 토글 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 즐겨찾기 설정에 실패했어요'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '식당 검색',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          
          // 검색바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '식당 이름 검색 (예: 은희네, 맘스터치)',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (mounted) {
                            setState(() {}); // suffixIcon 업데이트
                          }
                          _searchRestaurants('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
              onChanged: (value) {
                if (mounted) {
                  setState(() {}); // suffixIcon 업데이트
                }
                _searchRestaurants(value);
              },
              onSubmitted: (value) {
                _searchRestaurants(value);
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 결과 리스트
          Expanded(
            child: _buildSearchResults(),
          ),
          
          // 하단 여백 (Safe Area 고려)
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // 초기 로딩 제거 - 즉시 검색창 표시

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty ? Icons.search : Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty 
                  ? '검색어를 입력하세요'
                  : '검색 결과가 없어요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? '식당 이름을 검색해보세요 (예: 은희네, 맘스터치)'
                  : '다른 검색어를 시도해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final restaurant = _searchResults[index];
        return _buildRestaurantCard(restaurant);
      },
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onRestaurantSelected(restaurant);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                // 식당 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.restaurant,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // 식당 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.shortCategory,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // 기본 정보 표시
                      Text(
                        (restaurant.phone?.isNotEmpty == true) ? restaurant.phone! : '전화번호 정보 없음',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 즐겨찾기 및 거리 정보
                Column(
                  children: [
                    // 즐겨찾기 버튼
                    if (_currentUserId != null)
                      GestureDetector(
                        onTap: () => _toggleFavorite(restaurant),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _favoriteRestaurantIds.contains(restaurant.id)
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _favoriteRestaurantIds.contains(restaurant.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _favoriteRestaurantIds.contains(restaurant.id)
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            size: 20,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    
                    // 거리 정보
                    if (restaurant.formattedDistance.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          restaurant.formattedDistance,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.outline,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}