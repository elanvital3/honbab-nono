import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/kakao_search_service.dart';

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
  List<Restaurant> _popularRestaurants = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _loadPopularRestaurants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularRestaurants() async {
    setState(() {
      _isInitialLoading = true;
    });

    try {
      final results = await KakaoSearchService.searchNearbyRestaurants(size: 10);
      setState(() {
        _popularRestaurants = results;
        _searchResults = results;
        _isInitialLoading = false;
      });
    } catch (e) {
      print('❌ 인기 식당 로딩 에러: $e');
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _searchRestaurants(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = _popularRestaurants;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await KakaoSearchService.searchRestaurants(
        query: query.trim(),
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 식당 검색 에러: $e');
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _searchByCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    try {
      final results = await KakaoSearchService.searchByCategory(category: category);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 카테고리 검색 에러: $e');
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
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
                hintText: '식당 이름을 검색하세요',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {}); // suffixIcon 업데이트
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
                setState(() {}); // suffixIcon 업데이트
                _searchRestaurants(value);
              },
              onSubmitted: (value) {
                _searchRestaurants(value);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 카테고리 필터
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: KakaoSearchService.popularCategories.length,
              itemBuilder: (context, index) {
                final category = KakaoSearchService.popularCategories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _searchByCategory(category);
                      } else {
                        setState(() {
                          _selectedCategory = '';
                        });
                        _searchRestaurants(_searchController.text);
                      }
                    },
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 결과 리스트
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('근처 맛집을 찾고 있어요...'),
          ],
        ),
      );
    }

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
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty 
                  ? '근처 맛집을 찾을 수 없어요'
                  : '검색 결과가 없어요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 검색어를 시도해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
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
                    ],
                  ),
                ),
                
                // 거리 정보
                Column(
                  children: [
                    if (restaurant.displayDistance.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          restaurant.displayDistance,
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