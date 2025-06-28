import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/restaurant.dart';

class RestaurantService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'restaurants';

  /// 식당 검색 (전국 or 특정 도시)
  static Future<List<Restaurant>> searchRestaurants({
    required String query,
    String? city,
    String? province,
    int limit = 20,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 식당 검색: $query, 도시: $city, 도: $province');
      }

      Query restaurantQuery = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true);

      // 도시 필터
      if (city != null && city.isNotEmpty) {
        restaurantQuery = restaurantQuery.where('city', isEqualTo: city);
      }

      // 도/특별시 필터
      if (province != null && province.isNotEmpty) {
        restaurantQuery = restaurantQuery.where('province', isEqualTo: province);
      }

      // 검색어 필터 (이름 기준)
      if (query.isNotEmpty) {
        // Firestore는 부분 문자열 검색이 제한적이므로
        // 검색어의 첫 글자부터 시작하는 범위 쿼리 사용
        final queryLower = query.toLowerCase();
        final queryEnd = queryLower.substring(0, queryLower.length - 1) +
            String.fromCharCode(queryLower.codeUnitAt(queryLower.length - 1) + 1);
        
        restaurantQuery = restaurantQuery
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThan: queryEnd);
      }

      final querySnapshot = await restaurantQuery.limit(limit).get();

      final restaurants = querySnapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((restaurant) => 
              query.isEmpty || 
              restaurant.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // 거리순 정렬 (거리 정보가 있는 경우)
      restaurants.sort((a, b) {
        final aDistance = int.tryParse(a.distance ?? '0') ?? 0;
        final bDistance = int.tryParse(b.distance ?? '0') ?? 0;
        return aDistance.compareTo(bDistance);
      });

      if (kDebugMode) {
        print('✅ 검색 결과: ${restaurants.length}개 식당');
      }

      return restaurants;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 검색 에러: $e');
      }
      return [];
    }
  }

  /// 특정 지역의 인기 식당 (검색어 없이)
  static Future<List<Restaurant>> getPopularRestaurants({
    String? city,
    String? province,
    int limit = 15,
  }) async {
    try {
      Query restaurantQuery = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true);

      // 지역 필터
      if (city != null && city.isNotEmpty) {
        restaurantQuery = restaurantQuery.where('city', isEqualTo: city);
      } else if (province != null && province.isNotEmpty) {
        restaurantQuery = restaurantQuery.where('province', isEqualTo: province);
      }

      // 거리순 정렬 후 제한
      final querySnapshot = await restaurantQuery
          .orderBy('distance')
          .limit(limit)
          .get();

      final restaurants = querySnapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (kDebugMode) {
        print('✅ 인기 식당 ${restaurants.length}개 로드됨');
      }

      return restaurants;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 인기 식당 로드 에러: $e');
      }
      return [];
    }
  }

  /// 카테고리별 식당 검색
  static Future<List<Restaurant>> searchByCategory({
    required String category,
    String? city,
    String? province,
    int limit = 20,
  }) async {
    try {
      Query restaurantQuery = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('category', arrayContains: category);

      // 지역 필터
      if (city != null && city.isNotEmpty) {
        restaurantQuery = restaurantQuery.where('city', isEqualTo: city);
      } else if (province != null && province.isNotEmpty) {
        restaurantQuery = restaurantQuery.where('province', isEqualTo: province);
      }

      final querySnapshot = await restaurantQuery.limit(limit).get();

      final restaurants = querySnapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // 거리순 정렬
      restaurants.sort((a, b) {
        final aDistance = int.tryParse(a.distance ?? '0') ?? 0;
        final bDistance = int.tryParse(b.distance ?? '0') ?? 0;
        return aDistance.compareTo(bDistance);
      });

      if (kDebugMode) {
        print('✅ $category 검색 결과: ${restaurants.length}개');
      }

      return restaurants;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 카테고리 검색 에러: $e');
      }
      return [];
    }
  }

  /// 특정 식당 정보 가져오기
  static Future<Restaurant?> getRestaurant(String restaurantId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(restaurantId)
          .get();

      if (doc.exists) {
        return Restaurant.fromFirestore(doc.data()!, doc.id);
      }

      return null;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 정보 로드 에러: $e');
      }
      return null;
    }
  }

  /// 식당 데이터 업데이트 상태 확인
  static Future<DateTime?> getLastUpdateTime() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final timestamp = data['updatedAt'] as Timestamp?;
        return timestamp?.toDate();
      }

      return null;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 업데이트 시간 확인 에러: $e');
      }
      return null;
    }
  }

  /// 전체 식당 수 가져오기
  static Future<int> getTotalRestaurantCount() async {
    try {
      final aggregateQuery = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return aggregateQuery.count ?? 0;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 수 확인 에러: $e');
      }
      return 0;
    }
  }

  /// 도시별 식당 수 통계
  static Future<Map<String, int>> getCityStatistics() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final cityStats = <String, int>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final city = data['city'] as String? ?? '기타';
        cityStats[city] = (cityStats[city] ?? 0) + 1;
      }

      return cityStats;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 도시별 통계 에러: $e');
      }
      return {};
    }
  }

  /// 수동 데이터 업데이트 트리거 (개발/테스트용)
  static Future<bool> triggerManualUpdate({String? city}) async {
    try {
      // Firebase Functions의 updateRestaurantsManual 엔드포인트 호출
      // 실제 프로덕션에서는 HTTP 패키지를 사용해서 Functions 호출
      if (kDebugMode) {
        print('🔧 수동 업데이트 트리거: ${city ?? "전체"}');
      }
      
      // 여기서는 로그만 출력하고 true 반환
      // 실제로는 HTTP 요청을 통해 Functions 호출
      return true;

    } catch (e) {
      if (kDebugMode) {
        print('❌ 수동 업데이트 트리거 에러: $e');
      }
      return false;
    }
  }
}