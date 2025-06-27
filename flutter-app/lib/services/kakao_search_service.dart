import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';

class KakaoSearchService {
  static const String _baseUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
  static const String _apiKey = 'c73d308c736b033acf2208469891f0e0'; // REST API 키 사용
  
  // 현재 위치 (서울시청 기본값)
  static double _currentLatitude = 37.5665;
  static double _currentLongitude = 126.9780;
  
  static void setCurrentLocation(double latitude, double longitude) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
  }

  static Future<List<Restaurant>> searchRestaurants({
    required String query,
    int page = 1,
    int size = 15,
    String? category,
  }) async {
    try {
      // 카테고리가 지정된 경우 쿼리에 추가
      String searchQuery = query;
      if (category != null && category.isNotEmpty) {
        searchQuery = '$category $query';
      }
      
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'query': searchQuery,
        'x': _currentLongitude.toString(),
        'y': _currentLatitude.toString(),
        'radius': '20000', // 20km 반경
        'page': page.toString(),
        'size': size.toString(),
        'sort': 'distance', // 거리순 정렬
      });

      print('🔍 카카오 검색 요청: $searchQuery');
      print('📍 현재 위치: $_currentLatitude, $_currentLongitude');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
          'Content-Type': 'application/json;charset=UTF-8',
          'User-Agent': 'HonbabNoNo/1.0 (Android; Mobile)',
          'KA': 'sdk/1.0 os/android lang/ko-KR device/Mobile origin/com.honbabnono.honbab_nono',
        },
      );

      print('📡 카카오 API 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;
        
        print('📍 검색 결과: ${documents.length}개');
        
        final restaurants = documents
            .map((doc) => Restaurant.fromJson(doc))
            .where((restaurant) => _isRestaurant(restaurant.category))
            .toList();

        print('🍽️ 식당 필터링 후: ${restaurants.length}개');
        return restaurants;
      } else {
        print('❌ 카카오 API 에러: ${response.statusCode}');
        print('❌ 응답 내용: ${response.body}');
        print('🔄 샘플 데이터로 대체합니다...');
        return _searchSampleData(query, category);
      }
    } catch (e) {
      print('❌ 검색 에러: $e');
      print('🔄 샘플 데이터로 대체합니다...');
      return _searchSampleData(query, category);
    }
  }

  // 인기 카테고리별 검색
  static Future<List<Restaurant>> searchByCategory({
    required String category,
    int page = 1,
    int size = 15,
  }) async {
    return searchRestaurants(
      query: category,
      page: page,
      size: size,
      category: category,
    );
  }

  // 근처 식당 검색 (카테고리 없이)
  static Future<List<Restaurant>> searchNearbyRestaurants({
    int page = 1,
    int size = 15,
  }) async {
    return searchRestaurants(
      query: '맛집',
      page: page,
      size: size,
    );
  }

  // 식당 카테고리인지 확인
  static bool _isRestaurant(String category) {
    const restaurantKeywords = [
      '음식점',
      '카페',
      '디저트',
      '베이커리',
      '술집',
      '바',
      '맛집',
      '치킨',
      '피자',
      '햄버거',
      '분식',
      '한식',
      '중식',
      '일식',
      '양식',
      '패스트푸드',
      '레스토랑',
      '뷔페',
      '고기',
      '해산물',
      '아이스크림',
      '커피',
      '차',
    ];
    
    return restaurantKeywords.any((keyword) => 
      category.toLowerCase().contains(keyword.toLowerCase())
    );
  }

  // 인기 검색 카테고리
  static const List<String> popularCategories = [
    '한식',
    '일식',
    '중식',
    '양식',
    '카페',
    '치킨',
    '피자',
    '분식',
    '디저트',
    '술집',
  ];

  // 샘플 식당 데이터 (API 실패 시 사용)
  static List<Restaurant> _getSampleRestaurants() {
    return [
      Restaurant(
        id: 'sample_1',
        name: '강남 삼겹살 맛집',
        address: '서울 강남구 역삼동 123-45',
        latitude: 37.5665 + (0.001 * 1),
        longitude: 126.9780 + (0.001 * 1),
        category: '음식점 > 한식 > 고기구이',
        phone: '02-123-4567',
        distance: '150',
      ),
      Restaurant(
        id: 'sample_2',
        name: '홍대 피자헤븐',
        address: '서울 마포구 홍익로 234-56',
        latitude: 37.5565 + (0.001 * 2),
        longitude: 126.9280 + (0.001 * 2),
        category: '음식점 > 양식 > 피자',
        phone: '02-234-5678',
        distance: '1200',
      ),
      Restaurant(
        id: 'sample_3',
        name: '성수동 카페거리',
        address: '서울 성동구 성수동2가 345-67',
        latitude: 37.5465 + (0.001 * 3),
        longitude: 127.0380 + (0.001 * 3),
        category: '음식점 > 카페 > 커피전문점',
        phone: '02-345-6789',
        distance: '800',
      ),
      Restaurant(
        id: 'sample_4',
        name: '이태원 일식당',
        address: '서울 용산구 이태원동 456-78',
        latitude: 37.5365 + (0.001 * 4),
        longitude: 126.9980 + (0.001 * 4),
        category: '음식점 > 일식 > 초밥',
        phone: '02-456-7890',
        distance: '650',
      ),
      Restaurant(
        id: 'sample_5',
        name: '명동 교자',
        address: '서울 중구 명동2가 567-89',
        latitude: 37.5665 + (0.001 * 5),
        longitude: 126.9880 + (0.001 * 5),
        category: '음식점 > 중식 > 만두',
        phone: '02-567-8901',
        distance: '320',
      ),
      Restaurant(
        id: 'sample_6',
        name: '건대 치킨집',
        address: '서울 광진구 화양동 678-90',
        latitude: 37.5405 + (0.001 * 6),
        longitude: 127.0685 + (0.001 * 6),
        category: '음식점 > 치킨 > 프라이드치킨',
        phone: '02-678-9012',
        distance: '2100',
      ),
      Restaurant(
        id: 'sample_7',
        name: '압구정 브런치카페',
        address: '서울 강남구 압구정동 789-01',
        latitude: 37.5275 + (0.001 * 7),
        longitude: 127.0285 + (0.001 * 7),
        category: '음식점 > 카페 > 브런치',
        phone: '02-789-0123',
        distance: '1650',
      ),
      Restaurant(
        id: 'sample_8',
        name: '신촌 분식집',
        address: '서울 서대문구 신촌동 890-12',
        latitude: 37.5585 + (0.001 * 8),
        longitude: 126.9385 + (0.001 * 8),
        category: '음식점 > 분식 > 떡볶이',
        phone: '02-890-1234',
        distance: '890',
      ),
      Restaurant(
        id: 'sample_9',
        name: '여의도 스시로',
        address: '서울 영등포구 여의도동 901-23',
        latitude: 37.5185 + (0.001 * 9),
        longitude: 126.9085 + (0.001 * 9),
        category: '음식점 > 일식 > 회전초밥',
        phone: '02-901-2345',
        distance: '1780',
      ),
      Restaurant(
        id: 'sample_10',
        name: '망원동 맥주집',
        address: '서울 마포구 망원동 012-34',
        latitude: 37.5555 + (0.001 * 10),
        longitude: 126.9055 + (0.001 * 10),
        category: '음식점 > 술집 > 호프',
        phone: '02-012-3456',
        distance: '3200',
      ),
    ];
  }

  // 샘플 데이터에서 검색
  static List<Restaurant> _searchSampleData(String query, String? category) {
    final sampleData = _getSampleRestaurants();
    
    // 카테고리 필터링
    List<Restaurant> filtered = sampleData;
    if (category != null && category.isNotEmpty) {
      filtered = sampleData.where((restaurant) => 
        restaurant.category.toLowerCase().contains(category.toLowerCase())
      ).toList();
    }
    
    // 검색어 필터링
    if (query.isNotEmpty && query != '맛집') {
      filtered = filtered.where((restaurant) =>
        restaurant.name.toLowerCase().contains(query.toLowerCase()) ||
        restaurant.address.toLowerCase().contains(query.toLowerCase()) ||
        restaurant.category.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
    
    // 거리순 정렬
    filtered.sort((a, b) {
      final aDistance = int.tryParse(a.distance ?? '0') ?? 0;
      final bDistance = int.tryParse(b.distance ?? '0') ?? 0;
      return aDistance.compareTo(bDistance);
    });
    
    print('📍 샘플 데이터 검색 결과: ${filtered.length}개');
    return filtered;
  }
}