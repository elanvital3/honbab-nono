import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant_rating.dart';
import '../models/restaurant.dart';

class RestaurantRatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'restaurant_ratings';

  /// 식당 이름으로 평점 검색
  static Future<RestaurantRating?> getRatingByName(String restaurantName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('name', isGreaterThanOrEqualTo: restaurantName)
          .where('name', isLessThan: restaurantName + '\uf8ff')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return RestaurantRating.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('❌ 평점 검색 오류: $e');
      return null;
    }
  }

  /// 식당 이름 부분 일치로 평점 검색
  static Future<List<RestaurantRating>> searchRatingsByName(String restaurantName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('name', isGreaterThanOrEqualTo: restaurantName)
          .where('name', isLessThan: restaurantName + '\uf8ff')
          .orderBy('name')
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => RestaurantRating.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ 평점 검색 오류: $e');
      return [];
    }
  }

  /// 좌표 기반으로 근처 식당 평점 검색 (반경 5km)
  static Future<List<RestaurantRating>> getNearbyRatings(
    double latitude, 
    double longitude, 
    {double radiusKm = 5.0}
  ) async {
    try {
      // 간단한 bounding box 계산 (정밀하지 않지만 기본적인 필터링)
      final latDelta = radiusKm / 111.0; // 위도 1도 ≈ 111km
      final lngDelta = radiusKm / (111.0 * cos(latitude * pi / 180)); // 경도는 위도에 따라 달라짐
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('latitude', isGreaterThan: latitude - latDelta)
          .where('latitude', isLessThan: latitude + latDelta)
          .limit(50)
          .get();

      final ratings = querySnapshot.docs
          .map((doc) => RestaurantRating.fromFirestore(doc))
          .where((rating) {
            // 더 정확한 거리 계산으로 필터링
            final distance = _calculateDistance(
              latitude, longitude, 
              rating.latitude, rating.longitude
            );
            return distance <= radiusKm;
          })
          .toList();

      // 거리순 정렬
      ratings.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });

      return ratings;
    } catch (e) {
      print('❌ 근처 평점 검색 오류: $e');
      return [];
    }
  }

  /// Restaurant 객체와 매칭되는 평점 찾기
  static Future<RestaurantRating?> findMatchingRating(Restaurant restaurant) async {
    try {
      // 1. 정확한 이름 매칭 시도
      var rating = await getRatingByName(restaurant.name);
      if (rating != null) {
        print('✅ 정확한 이름 매칭: ${restaurant.name}');
        return rating;
      }

      // 2. 브랜드명 추출하여 매칭 시도
      final brandName = _extractBrandName(restaurant.name);
      if (brandName != restaurant.name) {
        rating = await getRatingByName(brandName);
        if (rating != null) {
          print('✅ 브랜드명 매칭: ${brandName}');
          return rating;
        }
      }

      // 3. 부분 문자열 매칭 시도
      final similarRatings = await searchRatingsByName(brandName);
      for (final similarRating in similarRatings) {
        if (_isNameSimilar(restaurant.name, similarRating.name)) {
          print('✅ 유사 이름 매칭: ${restaurant.name} ↔ ${similarRating.name}');
          return similarRating;
        }
      }

      // 4. 좌표 기반 매칭 시도 (반경 100m)
      final nearbyRatings = await getNearbyRatings(
        restaurant.latitude, 
        restaurant.longitude,
        radiusKm: 0.1 // 100m
      );
      
      for (final nearbyRating in nearbyRatings) {
        if (_isNameSimilar(restaurant.name, nearbyRating.name)) {
          print('✅ 위치 기반 매칭: ${restaurant.name} ↔ ${nearbyRating.name}');
          return nearbyRating;
        }
      }

      print('❌ 매칭되는 평점 없음: ${restaurant.name}');
      return null;
    } catch (e) {
      print('❌ 평점 매칭 오류: $e');
      return null;
    }
  }

  /// 최근 업데이트된 평점 데이터 조회
  static Future<List<RestaurantRating>> getRecentRatings({int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('lastUpdated', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => RestaurantRating.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ 최근 평점 조회 오류: $e');
      return [];
    }
  }

  /// 평점이 높은 식당 조회
  static Future<List<RestaurantRating>> getTopRatedRestaurants({int limit = 20}) async {
    try {
      final ratings = await getRecentRatings(limit: 100); // 더 많은 데이터 가져와서 필터링
      
      // 평점이 있는 것만 필터링하고 정렬
      final ratedRestaurants = ratings
          .where((rating) => rating.hasRating)
          .toList();

      ratedRestaurants.sort((a, b) {
        final scoreA = a.bestRating?.score ?? 0.0;
        final scoreB = b.bestRating?.score ?? 0.0;
        return scoreB.compareTo(scoreA); // 내림차순
      });

      return ratedRestaurants.take(limit).toList();
    } catch (e) {
      print('❌ 높은 평점 식당 조회 오류: $e');
      return [];
    }
  }

  /// 카테고리별 평점 조회
  static Future<List<RestaurantRating>> getRatingsByCategory(String category, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('category', isGreaterThanOrEqualTo: category)
          .where('category', isLessThan: category + '\uf8ff')
          .orderBy('category')
          .orderBy('lastUpdated', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => RestaurantRating.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ 카테고리별 평점 조회 오류: $e');
      return [];
    }
  }

  /// 테스트 데이터 추가 (개발용)
  static Future<void> addTestData() async {
    try {
      // functions/test_restaurant_ratings.json의 데이터를 Firestore에 추가
      final testRatings = [
        {
          'name': '은희네해장국 강남점',
          'address': '서울 강남구 테헤란로 123',
          'latitude': 37.5012743,
          'longitude': 127.0396587,
          'naverRating': {
            'score': 4.2,
            'reviewCount': 847,
            'url': 'https://map.naver.com/v5/entry/place/27184746'
          },
          'kakaoRating': {
            'score': 4.1,
            'reviewCount': 234,
            'url': 'https://place.map.kakao.com/27184746'
          },
          'category': '음식점 > 한식 > 해장국',
          'deepLinks': {
            'naver': 'nmap://place?id=27184746',
            'kakao': 'kakaomap://place?id=27184746'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '맘스터치 강남점',
          'address': '서울 강남구 역삼로 456',
          'latitude': 37.5001234,
          'longitude': 127.0385678,
          'naverRating': {
            'score': 4.0,
            'reviewCount': 523,
            'url': 'https://map.naver.com/v5/entry/place/12345678'
          },
          'kakaoRating': {
            'score': 3.9,
            'reviewCount': 198,
            'url': 'https://place.map.kakao.com/12345678'
          },
          'category': '음식점 > 패스트푸드 > 햄버거',
          'deepLinks': {
            'naver': 'nmap://place?id=12345678',
            'kakao': 'kakaomap://place?id=12345678'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '스타벅스 강남역점',
          'address': '서울 강남구 강남대로 789',
          'latitude': 37.4979876,
          'longitude': 127.0276543,
          'naverRating': {
            'score': 4.3,
            'reviewCount': 1256,
            'url': 'https://map.naver.com/v5/entry/place/87654321'
          },
          'kakaoRating': {
            'score': 4.2,
            'reviewCount': 876,
            'url': 'https://place.map.kakao.com/87654321'
          },
          'category': '음식점 > 카페 > 커피전문점',
          'deepLinks': {
            'naver': 'nmap://place?id=87654321',
            'kakao': 'kakaomap://place?id=87654321'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }
      ];

      for (int i = 0; i < testRatings.length; i++) {
        final docId = 'test_rating_${i + 1}';
        await _firestore.collection(_collectionName).doc(docId).set(testRatings[i]);
      }

      print('✅ 테스트 데이터 ${testRatings.length}개 추가 완료');
    } catch (e) {
      print('❌ 테스트 데이터 추가 오류: $e');
    }
  }

  // ========== 유틸리티 메서드 ==========

  /// 브랜드명 추출 (지점명 제거)
  static String _extractBrandName(String restaurantName) {
    // 지점명 패턴 제거
    final patterns = [
      RegExp(r'\s+\w+점$'),          // "강남점", "역삼점" 등
      RegExp(r'\s+\w+역점$'),        // "강남역점" 등  
      RegExp(r'\s+\w+지점$'),        // "강남지점" 등
      RegExp(r'\s+\w+매장$'),        // "강남매장" 등
      RegExp(r'\s+\w+점포$'),        // "강남점포" 등
      RegExp(r'\s+\d+호점$'),        // "1호점", "2호점" 등
    ];

    String brandName = restaurantName;
    for (final pattern in patterns) {
      brandName = brandName.replaceAll(pattern, '');
    }

    return brandName.trim();
  }

  /// 이름 유사도 검사
  static bool _isNameSimilar(String name1, String name2) {
    final brand1 = _extractBrandName(name1.toLowerCase());
    final brand2 = _extractBrandName(name2.toLowerCase());
    
    // 정확히 일치
    if (brand1 == brand2) return true;
    
    // 하나가 다른 하나를 포함
    if (brand1.contains(brand2) || brand2.contains(brand1)) return true;
    
    // 공통 키워드 3글자 이상
    final minLength = 3;
    if (brand1.length >= minLength && brand2.length >= minLength) {
      return brand1.substring(0, minLength) == brand2.substring(0, minLength);
    }
    
    return false;
  }

  /// 두 좌표 간의 거리 계산 (Haversine 공식)
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}