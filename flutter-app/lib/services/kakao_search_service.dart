import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';
import 'location_service.dart';

class KakaoSearchService {
  static const String _baseUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
  static const String _apiKey = 'c73d308c736b033acf2208469891f0e0'; // REST API 키 사용 - ⚠️ 유효성 확인 필요!
  
  // 현재 선택된 지역 (기본: null = GPS 위치 사용)
  static String? _selectedCity;
  
  static void setSelectedCity(String? cityName) {
    _selectedCity = cityName;
  }
  
  static String? get selectedCity => _selectedCity;

  // 간단한 키워드 검색 테스트 함수
  static Future<void> testKeywordSearch() async {
    final testKeywords = ['맛집', '카페', '은희네', '맘스터치'];
    
    for (final keyword in testKeywords) {
      print('\n🔍 "$keyword" 검색 테스트 시작...');
      try {
        final results = await searchRestaurants(
          query: keyword,
          size: 3,
          nationwide: true,
        );
        print('✅ "$keyword" 검색 결과: ${results.length}개');
        if (results.isNotEmpty) {
          print('   첫 번째 결과: ${results.first.name}');
        }
      } catch (e) {
        print('❌ "$keyword" 검색 실패: $e');
      }
    }
  }

  // API 키 유효성 테스트 함수
  static Future<bool> testApiKey() async {
    try {
      print('🔑 카카오 API 키 유효성 테스트 시작...');
      
      // 간단한 테스트 요청 (서울역 검색)
      final testUri = Uri.parse(_baseUrl).replace(queryParameters: {
        'query': '서울역',
        'x': '126.9780',
        'y': '37.5665',
        'size': '1',
      });
      
      print('🌐 테스트 URL: $testUri');
      
      final response = await http.get(
        testUri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
        },
      );
      
      print('📡 테스트 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;
        print('✅ API 키 유효! 테스트 검색 결과: ${documents.length}개');
        return true;
      } else {
        print('❌ API 키 무효 - 상태코드: ${response.statusCode}');
        print('❌ 에러 내용: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ API 키 테스트 중 오류: $e');
      return false;
    }
  }

  static Future<List<Restaurant>> searchRestaurants({
    required String query,
    int page = 1,
    int size = 15,
    String? category,
    bool nationwide = true, // 전국 검색 여부
  }) async {
    // size 파라미터 유효성 검사 (카카오 API 최대 15개 제한)
    if (size > 15) {
      print('⚠️ size 파라미터 $size는 15보다 클 수 없습니다. 15로 조정합니다.');
      size = 15;
    }
    if (size < 1) {
      print('⚠️ size 파라미터 $size는 1보다 작을 수 없습니다. 1로 조정합니다.');
      size = 1;
    }
    try {
      // 사용자 현재 위치 가져오기 (거리 계산용)
      final userLocation = await LocationService.getCurrentLocation();
      
      // 검색 위치 가져오기 (에뮬레이터는 해외 위치이므로 서울로 고정)
      final searchLocation = await LocationService.getLocationForSearch(
        selectedCity: _selectedCity ?? '서울시', // 기본값을 서울시로 설정
      );
      
      final latitude = searchLocation['lat']!;
      final longitude = searchLocation['lng']!;
      
      // 카테고리가 지정된 경우 쿼리에 추가
      String searchQuery = query;
      if (category != null && category.isNotEmpty) {
        searchQuery = '$category $query';
      }
      
      // 전국 검색 시 radius 파라미터 제거, 지역 검색 시 20km 반경
      final queryParams = <String, String>{
        'query': searchQuery,
        'x': longitude.toString(),
        'y': latitude.toString(),
        'page': page.toString(),
        'size': size.toString(),
        'sort': 'distance', // 거리순 정렬
      };
      
      // 지역 제한 검색인 경우에만 radius 추가
      if (!nationwide) {
        queryParams['radius'] = '20000'; // 20km 반경
      }
      
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
        },
      );

      if (response.statusCode != 200) {
        print('❌ 카카오 API 에러: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;
        
        final allRestaurants = documents.map((doc) => Restaurant.fromJson(doc)).toList();
        
        final restaurants = allRestaurants
            .where((restaurant) => _isRestaurant(restaurant.category))
            .toList();

        // 사용자 현재 위치가 있으면 실제 거리 계산 및 업데이트
        if (userLocation != null) {
          for (final restaurant in restaurants) {
            final distance = LocationService.calculateDistance(
              userLocation.latitude!,
              userLocation.longitude!,
              restaurant.latitude,
              restaurant.longitude,
            );
            
            // Restaurant 객체의 거리 정보 업데이트
            restaurant.distance = distance.round().toString();
            restaurant.displayDistance = LocationService.formatDistance(distance);
          }
          
          // 실제 거리 기준으로 재정렬 (가까운 순)
          restaurants.sort((a, b) {
            final aDistance = double.tryParse(a.distance ?? '0') ?? 0;
            final bDistance = double.tryParse(b.distance ?? '0') ?? 0;
            return aDistance.compareTo(bDistance);
          });
        }

        return restaurants;
      } else {
        return _searchSampleData(query, category, _selectedCity);
      }
    } catch (e) {
      return _searchSampleData(query, category, _selectedCity);
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

  // 식당 카테고리인지 확인 (완화된 필터링)
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
      '해장국',
      '라면',
      '냉면',
      '국밥',
      '김밥',
      '찌개',
      '전골',
      '탕',
      '갈비',
      '삼겹살',
      '스테이크',
      '돈까스',
      '족발',
      '보쌈',
      '찜',
      '회',
      '초밥',
      '우동',
      '라멘',
      '돈부리',
      '짜장면',
      '짬뽕',
      '탕수육',
      '파스타',
      '스파게티',
      '리조또',
      '샐러드',
      '샌드위치',
      '버거',
      '도넛',
      '빵',
      '케이크',
      '쿠키',
      '마카롱',
      '빙수',
      '팥빙수',
      '음료',
      '주류',
      '맥주',
      '소주',
      '와인',
      '칵테일',
    ];
    
    // 키워드 매칭 실패 시에도 기본적으로 허용 (너무 엄격하지 않게)
    return restaurantKeywords.any((keyword) => 
      category.toLowerCase().contains(keyword.toLowerCase())
    ) || category.isEmpty; // 빈 카테고리도 허용
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
  static List<Restaurant> _getSampleRestaurants(String? selectedCity) {
    // 선택된 도시에 따른 샘플 데이터 생성
    final cityCoords = (selectedCity != null && selectedCity != '전국') 
        ? LocationService.getCityCoordinates(selectedCity) 
        : LocationService.majorCities['서울시'];
    
    final baseLat = cityCoords?['lat'] ?? 37.5665;
    final baseLng = cityCoords?['lng'] ?? 126.9780;
    
    final cityName = (selectedCity == null || selectedCity == '전국') ? '서울' : selectedCity;
    return [
      // 실제 체인점들 (검색 테스트용)
      Restaurant(
        id: 'sample_eunhee_1',
        name: '은희네해장국 $cityName점',
        address: '$cityName 중구 남대문로 123-45',
        latitude: baseLat + (0.001 * 1),
        longitude: baseLng + (0.001 * 1),
        category: '음식점 > 한식 > 해장국',
        phone: '02-123-4567',
        distance: '150',
      ),
      Restaurant(
        id: 'sample_eunhee_2',
        name: '은희네해장국 $cityName역점',
        address: '$cityName 강남구 테헤란로 234-56',
        latitude: baseLat + (0.001 * 2),
        longitude: baseLng + (0.001 * 2),
        category: '음식점 > 한식 > 해장국',
        phone: '02-234-5678',
        distance: '850',
      ),
      Restaurant(
        id: 'sample_moms_1',
        name: '맘스터치 $cityName점',
        address: '$cityName 서초구 강남대로 345-67',
        latitude: baseLat + (0.001 * 3),
        longitude: baseLng + (0.001 * 3),
        category: '음식점 > 패스트푸드 > 햄버거',
        phone: '02-345-6789',
        distance: '620',
      ),
      Restaurant(
        id: 'sample_moms_2',
        name: '맘스터치 $cityName역사점',
        address: '$cityName 종로구 종로 456-78',
        latitude: baseLat + (0.001 * 4),
        longitude: baseLng + (0.001 * 4),
        category: '음식점 > 패스트푸드 > 햄버거',
        phone: '02-456-7890',
        distance: '1200',
      ),
      Restaurant(
        id: 'sample_burger_1',
        name: '버거킹 $cityName점',
        address: '$cityName 마포구 홍대입구 567-89',
        latitude: baseLat + (0.001 * 5),
        longitude: baseLng + (0.001 * 5),
        category: '음식점 > 패스트푸드 > 햄버거',
        phone: '02-567-8901',
        distance: '980',
      ),
      Restaurant(
        id: 'sample_kfc_1',
        name: 'KFC $cityName점',
        address: '$cityName 영등포구 여의도 678-90',
        latitude: baseLat + (0.001 * 6),
        longitude: baseLng + (0.001 * 6),
        category: '음식점 > 패스트푸드 > 치킨',
        phone: '02-678-9012',
        distance: '1450',
      ),
      Restaurant(
        id: 'sample_lotte_1',
        name: '롯데리아 $cityName점',
        address: '$cityName 송파구 잠실 789-01',
        latitude: baseLat + (0.001 * 7),
        longitude: baseLng + (0.001 * 7),
        category: '음식점 > 패스트푸드 > 햄버거',
        phone: '02-789-0123',
        distance: '2100',
      ),
      Restaurant(
        id: 'sample_starbucks_1',
        name: '스타벅스 $cityName점',
        address: '$cityName 강동구 천호 890-12',
        latitude: baseLat + (0.001 * 8),
        longitude: baseLng + (0.001 * 8),
        category: '음식점 > 카페 > 커피전문점',
        phone: '02-890-1234',
        distance: '750',
      ),
      Restaurant(
        id: 'sample_ediya_1',
        name: '이디야커피 $cityName점',
        address: '$cityName 노원구 상계 901-23',
        latitude: baseLat + (0.001 * 9),
        longitude: baseLng + (0.001 * 9),
        category: '음식점 > 카페 > 커피전문점',
        phone: '02-901-2345',
        distance: '1680',
      ),
      Restaurant(
        id: 'sample_kimbap_1',
        name: '김밥천국 $cityName점',
        address: '$cityName 동작구 사당 012-34',
        latitude: baseLat + (0.001 * 10),
        longitude: baseLng + (0.001 * 10),
        category: '음식점 > 분식 > 김밥',
        phone: '02-012-3456',
        distance: '320',
      ),
      Restaurant(
        id: 'sample_pizza_1',
        name: '피자헛 $cityName점',
        address: '$cityName 관악구 신림 113-45',
        latitude: baseLat + (0.001 * 11),
        longitude: baseLng + (0.001 * 11),
        category: '음식점 > 양식 > 피자',
        phone: '02-113-4567',
        distance: '1250',
      ),
      Restaurant(
        id: 'sample_domino_1',
        name: '도미노피자 $cityName점',
        address: '$cityName 구로구 구로 214-56',
        latitude: baseLat + (0.001 * 12),
        longitude: baseLng + (0.001 * 12),
        category: '음식점 > 양식 > 피자',
        phone: '02-214-5678',
        distance: '1890',
      ),
    ];
  }

  // 샘플 데이터에서 검색
  static List<Restaurant> _searchSampleData(String query, String? category, String? selectedCity) {
    final sampleData = _getSampleRestaurants(selectedCity);
    
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
    
    return filtered;
  }
}