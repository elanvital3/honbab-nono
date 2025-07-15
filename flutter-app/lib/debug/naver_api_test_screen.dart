import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class NaverApiTestScreen extends StatefulWidget {
  const NaverApiTestScreen({super.key});

  @override
  State<NaverApiTestScreen> createState() => _NaverApiTestScreenState();
}

class _NaverApiTestScreenState extends State<NaverApiTestScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _searchResults;
  String? _errorMessage;

  // 네이버 API 키 설정
  static const String _clientId = String.fromEnvironment('NAVER_CLIENT_ID', defaultValue: 'Hf3AWGaBRFz0FTSb9hCg');
  static const String _clientSecret = String.fromEnvironment('NAVER_CLIENT_SECRET', defaultValue: 'aW3TG3ZpPg');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchRestaurants() async {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색어를 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = null;
    });

    try {
      // 1단계: 네이버 Local Search API - 기본 검색
      await _performLocalSearch();
      
      // 2단계: 첫 번째 결과에 대해 플레이스 상세 정보 테스트
      if (_searchResults != null && 
          _searchResults!['items'] != null && 
          _searchResults!['items'].isNotEmpty) {
        await _testPlaceDetails();
      }
      
    } catch (e) {
      print('❌ 네이버 API 요청 실패: $e');
      setState(() {
        _errorMessage = '네트워크 오류: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _performLocalSearch() async {
    final query = '${_searchController.text.trim()} 맛집';
    final encodedQuery = Uri.encodeQueryComponent(query);
    
    final url = 'https://openapi.naver.com/v1/search/local.json?query=$encodedQuery&display=5&start=1&sort=random';
    
    print('\n🔍 === 1단계: Local Search API ===');
    print('🔍 요청 URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'X-Naver-Client-Id': _clientId,
        'X-Naver-Client-Secret': _clientSecret,
        'Content-Type': 'application/json',
      },
    );

    print('📊 응답 코드: ${response.statusCode}');
    print('📊 응답 바디: ${response.body}');

    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body);
      setState(() {
        _searchResults = decodedData;
      });
      
      print('✅ Local Search 성공 - 총 ${decodedData['total']}개 결과');
      
      // 첫 번째 결과 상세 분석
      if (decodedData['items'] != null && decodedData['items'].isNotEmpty) {
        final firstItem = decodedData['items'][0];
        print('🔍 첫 번째 결과 상세:');
        firstItem.forEach((key, value) {
          print('   $key: $value');
        });
      }
      
    } else {
      setState(() {
        _errorMessage = '네이버 Local Search 오류: ${response.statusCode}\n${response.body}';
        _isLoading = false;
      });
      throw Exception('Local Search failed');
    }
  }

  Future<void> _testPlaceDetails() async {
    print('\n🏪 === 2단계: Place Details API 테스트 ===');
    
    final firstItem = _searchResults!['items'][0] as Map<String, dynamic>;
    final placeName = firstItem['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '';
    final placeAddress = firstItem['address'] ?? '';
    
    print('🏪 대상 업체: $placeName');
    print('📍 주소: $placeAddress');
    
    // 네이버 플레이스 API는 공식적으로 제공되지 않으므로
    // 대신 다른 방법들을 테스트해보겠습니다
    await _testAlternativeApis(placeName, placeAddress);
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testAlternativeApis(String placeName, String address) async {
    print('\n🔍 === 3단계: 대안 API 테스트 ===');
    
    // 1. 네이버 블로그 검색으로 후기 찾기
    await _searchNaverBlogs(placeName);
    
    // 2. 네이버 뉴스 검색으로 관련 기사 찾기  
    await _searchNaverNews(placeName);
    
    // 3. 네이버 쇼핑 검색으로 관련 상품 찾기 (배달 등)
    await _searchNaverShopping(placeName);
  }

  Future<void> _searchNaverBlogs(String placeName) async {
    try {
      final query = Uri.encodeQueryComponent('$placeName 후기');
      final url = 'https://openapi.naver.com/v1/search/blog.json?query=$query&display=3';
      
      print('\n📝 블로그 검색 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 블로그 검색 성공: ${data['total']}개 블로그 포스트');
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          final blog = data['items'][0];
          print('📝 대표 블로그: ${blog['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '')}');
          print('📝 블로그 설명: ${blog['description']?.toString().replaceAll(RegExp(r'<[^>]*>'), '')}');
        }
        
        // 검색 결과에 블로그 정보 추가
        _searchResults!['blogs'] = data['items'];
      }
    } catch (e) {
      print('❌ 블로그 검색 실패: $e');
    }
  }

  Future<void> _searchNaverNews(String placeName) async {
    try {
      final query = Uri.encodeQueryComponent('$placeName 맛집');
      final url = 'https://openapi.naver.com/v1/search/news.json?query=$query&display=2';
      
      print('\n📰 뉴스 검색 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 뉴스 검색 성공: ${data['total']}개 뉴스');
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          final news = data['items'][0];
          print('📰 관련 뉴스: ${news['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '')}');
        }
        
        // 검색 결과에 뉴스 정보 추가
        _searchResults!['news'] = data['items'];
      }
    } catch (e) {
      print('❌ 뉴스 검색 실패: $e');
    }
  }

  Future<void> _searchNaverShopping(String placeName) async {
    try {
      final query = Uri.encodeQueryComponent('$placeName 배달');
      final url = 'https://openapi.naver.com/v1/search/shop.json?query=$query&display=2';
      
      print('\n🛒 쇼핑 검색 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 쇼핑 검색 성공: ${data['total']}개 상품');
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          final product = data['items'][0];
          print('🛒 관련 상품: ${product['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '')}');
          print('💰 가격: ${product['lprice']}원');
        }
        
        // 검색 결과에 쇼핑 정보 추가
        _searchResults!['shopping'] = data['items'];
      }
    } catch (e) {
      print('❌ 쇼핑 검색 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        title: Text(
          '네이버 API 테스트',
          style: AppTextStyles.titleLarge,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검색 입력 영역
            _buildSearchInput(),
            
            const SizedBox(height: 24),
            
            // 결과 표시 영역
            Expanded(
              child: _buildResultsArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '네이버 통합 API 테스트',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          '맛집 검색 + 블로그 후기 + 뉴스 + 쇼핑 정보까지!',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppDesignTokens.onSurfaceVariant,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '예: 강남 맛집, 대춘해장국',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppDesignTokens.primary),
                  ),
                ),
                onSubmitted: (_) => _searchRestaurants(),
              ),
            ),
            
            const SizedBox(width: 12),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _searchRestaurants,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('검색'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    
    if (_searchResults == null) {
      return _buildInitialMessage();
    }
    
    return _buildSearchResults();
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 48,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            '오류 발생',
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _errorMessage!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.red.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppDesignTokens.onSurfaceVariant,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            '네이버 API 테스트',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '검색어를 입력하고 네이버에서\n어떤 데이터를 가져올 수 있는지 확인해보세요',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final items = _searchResults!['items'] as List?;
    final total = _searchResults!['total'] ?? 0;
    final start = _searchResults!['start'] ?? 1;
    final display = _searchResults!['display'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 검색 결과 헤더
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesignTokens.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              
              const SizedBox(width: 8),
              
              Text(
                '총 $total개 결과 중 $start~${start + display - 1}번째',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppDesignTokens.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 검색 결과 리스트
        Expanded(
          child: items == null || items.isEmpty
              ? Center(
                  child: Text(
                    '검색 결과가 없습니다',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppDesignTokens.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    return _buildResultItem(item, index + 1);
                  },
                ),
        ),
        
        // 추가 정보 섹션들
        if (_searchResults!.containsKey('blogs') ||
            _searchResults!.containsKey('news') ||
            _searchResults!.containsKey('shopping')) ...[
          const SizedBox(height: 24),
          _buildAdditionalInfoSections(),
        ],
      ],
    );
  }

  Widget _buildResultItem(Map<String, dynamic> item, int index) {
    // HTML 태그 제거 함수
    String removeHtmlTags(String htmlString) {
      return htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    }

    final title = removeHtmlTags(item['title'] ?? '');
    final category = item['category'] ?? '';
    final address = item['address'] ?? '';
    final roadAddress = item['roadAddress'] ?? '';
    final telephone = item['telephone'] ?? '';
    final mapx = item['mapx'] ?? '';
    final mapy = item['mapy'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignTokens.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목과 순번
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 상세 정보
          _buildInfoRow('카테고리', category),
          if (address.isNotEmpty) _buildInfoRow('지번주소', address),
          if (roadAddress.isNotEmpty) _buildInfoRow('도로명주소', roadAddress),
          if (telephone.isNotEmpty) _buildInfoRow('전화번호', telephone),
          _buildInfoRow('좌표', 'X: $mapx, Y: $mapy'),
          
          const SizedBox(height: 12),
          
          // 원본 데이터 표시 (개발용)
          ExpansionTile(
            title: Text(
              '원본 데이터 보기',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(item),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 추가 수집 정보',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 블로그 후기 섹션
        if (_searchResults!.containsKey('blogs'))
          _buildBlogSection(),
        
        // 뉴스 섹션  
        if (_searchResults!.containsKey('news'))
          _buildNewsSection(),
          
        // 쇼핑 정보 섹션
        if (_searchResults!.containsKey('shopping'))
          _buildShoppingSection(),
      ],
    );
  }

  Widget _buildBlogSection() {
    final blogs = _searchResults!['blogs'] as List;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.article,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '📝 블로그 후기 (${blogs.length}개)',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          ...blogs.take(2).map((blog) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blog['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  blog['description']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppDesignTokens.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildNewsSection() {
    final news = _searchResults!['news'] as List;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.newspaper,
                color: Colors.orange.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '📰 관련 뉴스 (${news.length}개)',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          ...news.take(1).map((article) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                article['description']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildShoppingSection() {
    final shopping = _searchResults!['shopping'] as List;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_cart,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '🛒 배달/상품 정보 (${shopping.length}개)',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          ...shopping.take(2).map((product) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💰 ${product['lprice'] ?? 0}원',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}