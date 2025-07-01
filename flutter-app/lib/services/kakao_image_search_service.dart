import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KakaoImageSearchService {
  static const String _baseUrl = 'https://dapi.kakao.com/v2/search/image';
  static String get _apiKey {
    final key = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
    if (key.isEmpty) {
      print('⚠️ KAKAO_REST_API_KEY 환경변수가 비어있음');
    }
    return key;
  }

  /// 식당 이름으로 대표 이미지 검색
  static Future<String?> searchRestaurantImage(String restaurantName) async {
    try {
      // 검색어 최적화: 여러 패턴으로 시도
      final searchQueries = [
        '$restaurantName 음식점',
        '$restaurantName 맛집', 
        '$restaurantName 식당',
        restaurantName, // 식당명만으로도 시도
      ];
      
      print('🔍 이미지 검색 시작: $restaurantName');
      
      // 여러 검색어로 순차 시도
      for (final searchQuery in searchQueries) {
        final imageUrl = await _searchWithQuery(searchQuery);
        if (imageUrl != null) {
          print('✅ 이미지 검색 성공: $searchQuery → $imageUrl');
          return imageUrl;
        }
        print('⚠️ 검색어 "$searchQuery" 결과 없음');
      }
      
      print('❌ 모든 검색어 실패: $restaurantName');
      return null;
    } catch (e) {
      print('❌ 이미지 검색 중 오류: $e');
      return null;
    }
  }
  
  /// 특정 검색어로 이미지 검색 (내부 함수)
  static Future<String?> _searchWithQuery(String searchQuery) async {
    try {
      print('🔍 검색어 시도: "$searchQuery"');
      
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'query': searchQuery,
        'sort': 'accuracy', // 정확도순 정렬
        'size': '5', // 5개 결과만 가져와서 첫 번째 사용
      });

      print('📡 요청 URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
        },
      );

      print('📡 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 응답 데이터: $data');
        
        final documents = data['documents'] as List;
        print('📸 검색된 이미지 수: ${documents.length}');
        
        if (documents.isNotEmpty) {
          // 첫 번째 이미지의 썸네일 URL 반환
          final firstImage = documents.first;
          final imageUrl = firstImage['thumbnail_url'] as String?;
          
          print('✅ 검색 성공: "$searchQuery" → $imageUrl');
          return imageUrl;
        } else {
          print('🔍 검색 결과 없음: "$searchQuery"');
          return null;
        }
      } else {
        print('❌ API 에러: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 검색 오류: $e');
      return null;
    }
  }

  /// 여러 식당의 이미지를 한 번에 검색 (배치 처리)
  static Future<Map<String, String?>> searchMultipleRestaurantImages(
    List<String> restaurantNames
  ) async {
    final results = <String, String?>{};
    
    // API 호출 제한을 고려하여 병렬로 처리하되 적당한 수준으로 제한
    final futures = restaurantNames.map((name) async {
      final imageUrl = await searchRestaurantImage(name);
      return MapEntry(name, imageUrl);
    });
    
    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }
    
    return results;
  }

  /// 이미지 URL 유효성 확인
  static Future<bool> isImageUrlValid(String imageUrl) async {
    try {
      final response = await http.head(Uri.parse(imageUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// API 키 및 기본 검색 테스트
  static Future<void> testImageSearch() async {
    print('🧪 카카오 이미지 검색 API 테스트 시작');
    
    final testQueries = ['맥도날드', '스타벅스', '치킨', '음식점'];
    
    for (final query in testQueries) {
      print('\n--- "$query" 테스트 ---');
      final result = await searchRestaurantImage(query);
      print('결과: ${result ?? "실패"}');
    }
  }

  /// 기본 fallback 이미지들 (카테고리별)
  static String getDefaultImageByCategory(String category) {
    // 카테고리에 따른 기본 이미지 (나중에 assets에 추가 예정)
    if (category.contains('한식')) {
      return 'assets/images/default_korean_food.jpg';
    } else if (category.contains('중식')) {
      return 'assets/images/default_chinese_food.jpg';
    } else if (category.contains('일식')) {
      return 'assets/images/default_japanese_food.jpg';
    } else if (category.contains('양식')) {
      return 'assets/images/default_western_food.jpg';
    } else if (category.contains('카페')) {
      return 'assets/images/default_cafe.jpg';
    } else if (category.contains('치킨')) {
      return 'assets/images/default_chicken.jpg';
    } else if (category.contains('피자')) {
      return 'assets/images/default_pizza.jpg';
    } else {
      return 'assets/images/default_restaurant.jpg';
    }
  }
}