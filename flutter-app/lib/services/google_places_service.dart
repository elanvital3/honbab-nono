import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/restaurant.dart';

class GooglePlacesService {
  static const String _baseUrl = 'https://places.googleapis.com/v1/places:searchText';
  static String get _apiKey {
    final key = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    if (key.isEmpty) {
      print('⚠️ GOOGLE_PLACES_API_KEY 환경변수가 비어있음');
    }
    return key;
  }

  /// 고품질 식당 검색 (4.3+ 평점, 100+ 리뷰)
  static Future<List<Restaurant>> searchHighQualityRestaurants({
    required String region,
    double minRating = 4.3,
    int minReviewCount = 100,
    int limit = 20,
  }) async {
    try {
      print('🔍 Google Places 고품질 식당 검색: $region (평점 $minRating+, 리뷰 $minReviewCount+)');
      
      // 지역별 좌표 설정 (대략적인 중심점)
      final coordinates = _getRegionCoordinates(region);
      if (coordinates == null) {
        print('❌ 지원하지 않는 지역: $region');
        return [];
      }

      final requestBody = {
        'textQuery': '$region 맛집 음식점',
        'includedType': 'restaurant',
        'minRating': minRating,
        'maxResultCount': limit * 3, // 리뷰 수 필터링을 위해 더 많이 가져옴
        'locationBias': {
          'circle': {
            'center': {
              'latitude': coordinates['lat'],
              'longitude': coordinates['lng']
            },
            'radius': 10000.0 // 10km 반경
          }
        },
        'languageCode': 'ko',
        'regionCode': 'KR'
      };

      print('📡 요청 데이터: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.types,places.photos,places.currentOpeningHours,places.regularOpeningHours,places.reviews'
        },
        body: json.encode(requestBody),
      );

      print('📡 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 응답 데이터: $data');
        
        final places = data['places'] as List? ?? [];
        print('🍽️ 검색된 식당 수: ${places.length}');
        
        final restaurants = <Restaurant>[];
        
        for (final place in places) {
          try {
            // 리뷰 수 필터링 (클라이언트 사이드)
            final userRatingCount = place['userRatingCount'] as int? ?? 0;
            if (userRatingCount < minReviewCount) {
              print('⚠️ 리뷰 수 부족: ${place['displayName']?['text']} ($userRatingCount < $minReviewCount)');
              continue;
            }

            final restaurant = _parseGooglePlaceToRestaurant(place);
            if (restaurant != null) {
              restaurants.add(restaurant);
              print('✅ 고품질 식당 추가: ${restaurant.name} (${restaurant.googlePlaces?.rating}⭐, ${restaurant.googlePlaces?.userRatingsTotal} 리뷰)');
            }
          } catch (e) {
            print('❌ 식당 파싱 오류: $e');
          }
        }
        
        // 최대 제한 적용
        final limitedResults = restaurants.take(limit).toList();
        print('🎯 최종 결과: ${limitedResults.length}개 고품질 식당');
        
        return limitedResults;
      } else {
        print('❌ Google Places API 에러: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Google Places 검색 중 오류: $e');
      return [];
    }
  }

  /// Google Place 데이터를 Restaurant 모델로 변환
  static Restaurant? _parseGooglePlaceToRestaurant(Map<String, dynamic> place) {
    try {
      final displayName = place['displayName']?['text'] as String?;
      final formattedAddress = place['formattedAddress'] as String?;
      final location = place['location'] as Map<String, dynamic>?;
      final rating = (place['rating'] as num?)?.toDouble();
      final userRatingCount = place['userRatingCount'] as int? ?? 0;
      final types = place['types'] as List? ?? [];
      final photos = place['photos'] as List? ?? [];

      if (displayName == null || formattedAddress == null || location == null) {
        print('❌ 필수 필드 누락: $place');
        return null;
      }

      final latitude = (location['latitude'] as num?)?.toDouble() ?? 0.0;
      final longitude = (location['longitude'] as num?)?.toDouble() ?? 0.0;

      // 카테고리 생성 (types에서 첫 번째 type 사용)
      String category = 'restaurant';
      if (types.isNotEmpty) {
        category = types.first.toString().replaceAll('_', ' ');
      }

      // 모든 사진 URL 가져오기 (최대 10장)
      final photoUrls = <String>[];
      String? imageUrl; // 대표 이미지 (첫 번째)
      
      for (final photo in photos) {
        final photoName = photo['name'] as String?;
        if (photoName != null) {
          final photoUrl = 'https://places.googleapis.com/v1/$photoName/media?maxHeightPx=400&maxWidthPx=600&key=$_apiKey';
          photoUrls.add(photoUrl);
          
          // 첫 번째 사진을 대표 이미지로 설정
          if (imageUrl == null) {
            imageUrl = photoUrl;
          }
        }
      }

      // 리뷰 데이터 파싱
      final reviewsList = <GoogleReview>[];
      final reviews = place['reviews'] as List? ?? [];
      
      print('🔍 리뷰 데이터 확인: ${reviews.length}개 리뷰 받음');
      
      for (int i = 0; i < reviews.length && i < 5; i++) { // 최대 5개 리뷰만
        try {
          final reviewData = reviews[i] as Map<String, dynamic>;
          print('🔍 리뷰 $i 원본 데이터: $reviewData');
          
          final review = GoogleReview.fromMap(reviewData);
          final textPreview = review.text.isNotEmpty 
              ? (review.text.length > 50 ? '${review.text.substring(0, 50)}...' : review.text)
              : '(텍스트 없음)';
          print('🔍 파싱된 리뷰: time=${review.time}, author=${review.authorName}, text=$textPreview');
          
          // formattedDate 테스트
          try {
            final formattedDate = review.formattedDate;
            print('🔍 포맷된 날짜: $formattedDate');
          } catch (e) {
            print('❌ 날짜 포맷팅 오류: $e');
          }
          
          // 모든 리뷰를 추가 (필터링 없음)
          reviewsList.add(review);
          print('✅ 리뷰 추가 완료');
        } catch (e) {
          print('❌ 리뷰 파싱 오류: $e');
        }
      }
      
      print('🔍 최종 추가된 리뷰 수: ${reviewsList.length}');
      if (reviewsList.isNotEmpty) {
        print('🔍 첫 번째 리뷰 미리보기: ${reviewsList.first.authorName} - ${reviewsList.first.formattedDate}');
      }

      // Google Places 데이터 객체 생성
      final googlePlacesData = GooglePlacesData(
        placeId: place['id'] as String?,
        rating: rating,
        userRatingsTotal: userRatingCount,
        reviews: reviewsList,
        photos: photoUrls,
        priceLevel: place['priceLevel'] as int?,
        isOpen: place['currentOpeningHours']?['openNow'] as bool?,
        phoneNumber: place['nationalPhoneNumber'] as String?,
        regularOpeningHours: place['regularOpeningHours'] as Map<String, dynamic>?,
        updatedAt: DateTime.now(),
      );

      return Restaurant(
        id: place['id'] as String? ?? 'google_${DateTime.now().millisecondsSinceEpoch}',
        name: displayName,
        address: formattedAddress,
        latitude: latitude,
        longitude: longitude,
        category: category,
        phone: place['nationalPhoneNumber'] as String?,
        url: null, // Google Places는 웹사이트 URL 별도 제공
        rating: rating,
        imageUrl: imageUrl,
        googlePlaces: googlePlacesData,
        // 기타 필드들은 null로 설정 (YouTube 데이터 없음)
        youtubeStats: null,
        featureTags: null,
        trendScore: null,
      );
    } catch (e) {
      print('❌ Google Place 파싱 오류: $e');
      return null;
    }
  }

  /// 지역별 좌표 반환
  static Map<String, double>? _getRegionCoordinates(String region) {
    final coordinates = {
      '제주도': {'lat': 33.4996, 'lng': 126.5312},
      '서울': {'lat': 37.5665, 'lng': 126.9780},
      '서울시': {'lat': 37.5665, 'lng': 126.9780},
      '부산': {'lat': 35.1796, 'lng': 129.0756},
      '부산시': {'lat': 35.1796, 'lng': 129.0756},
      '경주': {'lat': 35.8562, 'lng': 129.2247},
      '경주시': {'lat': 35.8562, 'lng': 129.2247},
      '대구': {'lat': 35.8722, 'lng': 128.6014},
      '대구시': {'lat': 35.8722, 'lng': 128.6014},
      '인천': {'lat': 37.4563, 'lng': 126.7052},
      '인천시': {'lat': 37.4563, 'lng': 126.7052},
      '광주': {'lat': 35.1595, 'lng': 126.8526},
      '광주시': {'lat': 35.1595, 'lng': 126.8526},
      '대전': {'lat': 36.3504, 'lng': 127.3845},
      '대전시': {'lat': 36.3504, 'lng': 127.3845},
      '울산': {'lat': 35.5384, 'lng': 129.3114},
      '울산시': {'lat': 35.5384, 'lng': 129.3114},
    };

    return coordinates[region];
  }

  /// API 키 테스트
  static Future<bool> testApiKey() async {
    try {
      print('🧪 Google Places API 키 테스트 시작');
      
      final requestBody = {
        'textQuery': '서울 맛집',
        'maxResultCount': 1,
        'languageCode': 'ko',
        'regionCode': 'KR'
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName'
        },
        body: json.encode(requestBody),
      );

      final isValid = response.statusCode == 200;
      print('🧪 API 키 테스트 결과: ${isValid ? "성공" : "실패"} (${response.statusCode})');
      
      if (!isValid) {
        print('❌ 응답: ${response.body}');
      }
      
      return isValid;
    } catch (e) {
      print('❌ API 키 테스트 오류: $e');
      return false;
    }
  }

  /// 캐시 키 생성
  static String _getCacheKey(String region, double minRating, int minReviewCount) {
    return 'google_places_${region}_${minRating}_${minReviewCount}';
  }

  /// 배치 검색 (여러 지역 동시 검색)
  static Future<Map<String, List<Restaurant>>> searchMultipleRegions({
    required List<String> regions,
    double minRating = 4.3,
    int minReviewCount = 100,
    int limitPerRegion = 10,
  }) async {
    print('🔍 Google Places 배치 검색: ${regions.length}개 지역');
    
    final results = <String, List<Restaurant>>{};
    
    // 병렬 처리로 API 호출 최적화
    final futures = regions.map((region) async {
      final restaurants = await searchHighQualityRestaurants(
        region: region,
        minRating: minRating,
        minReviewCount: minReviewCount,
        limit: limitPerRegion,
      );
      return MapEntry(region, restaurants);
    });

    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }

    print('🎯 배치 검색 완료: ${results.length}개 지역');
    return results;
  }

  /// 🧪 지역별 별점/리뷰수 필터링 샘플링 테스트
  static Future<void> testRegionSampling() async {
    print('\n🧪 === Google Places API 샘플링 테스트 시작 ===');
    
    // 테스트 시나리오
    final testCases = [
      {
        'region': '서울',
        'minRating': 4.3,
        'minReviewCount': 100,
        'limit': 10,
        'description': '서울 고품질 맛집 (4.3+ 별점, 100+ 리뷰)'
      },
      {
        'region': '부산',
        'minRating': 4.0,
        'minReviewCount': 50,
        'limit': 8,
        'description': '부산 인기 맛집 (4.0+ 별점, 50+ 리뷰)'
      },
      {
        'region': '제주도',
        'minRating': 4.5,
        'minReviewCount': 30,
        'limit': 5,
        'description': '제주도 최고급 맛집 (4.5+ 별점, 30+ 리뷰)'
      },
      {
        'region': '경주',
        'minRating': 4.2,
        'minReviewCount': 20,
        'limit': 6,
        'description': '경주 추천 맛집 (4.2+ 별점, 20+ 리뷰)'
      },
    ];

    final allResults = <String, List<Restaurant>>{};
    int totalRestaurants = 0;
    
    for (final testCase in testCases) {
      print('\n--- ${testCase['description']} ---');
      
      try {
        final restaurants = await searchHighQualityRestaurants(
          region: testCase['region'] as String,
          minRating: testCase['minRating'] as double,
          minReviewCount: testCase['minReviewCount'] as int,
          limit: testCase['limit'] as int,
        );
        
        allResults[testCase['region'] as String] = restaurants;
        totalRestaurants += restaurants.length;
        
        print('✅ 결과: ${restaurants.length}개 식당');
        
        // 상위 3개 식당 정보 출력
        for (int i = 0; i < restaurants.length && i < 3; i++) {
          final r = restaurants[i];
          final rating = r.googlePlaces?.rating?.toStringAsFixed(1) ?? 'N/A';
          final reviewCount = r.googlePlaces?.userRatingsTotal ?? 0;
          print('   ${i + 1}. ${r.name} (⭐ $rating, 📝 $reviewCount개 리뷰)');
          print('      📍 ${r.address}');
        }
        
        if (restaurants.length > 3) {
          print('   ... 그 외 ${restaurants.length - 3}개 더');
        }
        
      } catch (e) {
        print('❌ ${testCase['region']} 검색 실패: $e');
        allResults[testCase['region'] as String] = [];
      }
      
      // API 호출 간격 (Rate Limiting 방지)
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    print('\n🎯 === 테스트 요약 ===');
    print('총 ${allResults.length}개 지역에서 $totalRestaurants개 식당 발견');
    
    // 지역별 결과 요약
    allResults.forEach((region, restaurants) {
      print('  📍 $region: ${restaurants.length}개');
    });
    
    // 평점 분포 분석
    final allRestaurants = allResults.values.expand((list) => list).toList();
    if (allRestaurants.isNotEmpty) {
      final ratings = allRestaurants
          .where((r) => r.googlePlaces?.rating != null)
          .map((r) => r.googlePlaces!.rating!)
          .toList();
      
      if (ratings.isNotEmpty) {
        final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
        final maxRating = ratings.reduce((a, b) => a > b ? a : b);
        final minRating = ratings.reduce((a, b) => a < b ? a : b);
        
        print('\n📊 평점 분석:');
        print('  평균: ${avgRating.toStringAsFixed(2)}⭐');
        print('  최고: ${maxRating.toStringAsFixed(1)}⭐');
        print('  최저: ${minRating.toStringAsFixed(1)}⭐');
      }
    }
    
    print('\n🧪 === 샘플링 테스트 완료 ===\n');
  }

  /// 🧪 단일 지역 상세 테스트
  static Future<void> testSingleRegionDetail(String region) async {
    print('\n🔬 === $region 상세 테스트 ===');
    
    try {
      final restaurants = await searchHighQualityRestaurants(
        region: region,
        minRating: 4.0,
        minReviewCount: 50,
        limit: 15,
      );
      
      print('✅ $region에서 ${restaurants.length}개 고품질 식당 발견');
      
      // 상세 정보 출력
      for (int i = 0; i < restaurants.length; i++) {
        final r = restaurants[i];
        final places = r.googlePlaces;
        
        print('\n${i + 1}. 🍽️ ${r.name}');
        print('   📍 ${r.address}');
        print('   📂 ${r.category}');
        
        if (places != null) {
          if (places.rating != null) {
            print('   ⭐ ${places.rating!.toStringAsFixed(1)}/5.0');
          }
          print('   📝 ${places.userRatingsTotal}개 리뷰');
          
          if (places.priceLevel != null) {
            final price = '\$' * places.priceLevel!;
            print('   💰 $price');
          }
          
          if (places.isOpen != null) {
            print('   🕒 ${places.isOpen! ? "영업중" : "마감"}');
          }
          
          if (places.photos.isNotEmpty) {
            print('   📸 ${places.photos.length}개 사진');
          }
        }
        
        if (r.phone != null) {
          print('   📞 ${r.phone}');
        }
      }
      
    } catch (e) {
      print('❌ $region 상세 테스트 실패: $e');
    }
    
    print('\n🔬 === $region 상세 테스트 완료 ===\n');
  }
}