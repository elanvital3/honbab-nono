import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/restaurant.dart';
import 'user_service.dart';
import 'auth_service.dart';

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
      if (kDebugMode) {
        print('🔍 인기 식당 조회: city=$city, province=$province');
      }

      // 인덱스 문제 해결을 위해 간단한 쿼리만 사용
      Query restaurantQuery = _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true);

      // 정렬 없이 기본 쿼리만 실행
      final querySnapshot = await restaurantQuery.limit(30).get();

      List<Restaurant> allRestaurants = querySnapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // 앱에서 필터링 (지역별)
      List<Restaurant> filteredRestaurants = allRestaurants.where((restaurant) {
        if (city != null && city.isNotEmpty) {
          return restaurant.city == city;
        } else if (province != null && province.isNotEmpty) {
          return restaurant.province == province;
        }
        return true;
      }).toList();

      // 앱에서 정렬 (최신순)
      filteredRestaurants.sort((a, b) {
        final aTime = a.updatedAt ?? DateTime(2000);
        final bTime = b.updatedAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      // 제한
      final restaurants = filteredRestaurants.take(limit).toList();

      if (kDebugMode) {
        print('✅ 인기 식당 ${restaurants.length}개 로드됨 (전체: ${allRestaurants.length}개)');
        for (final restaurant in restaurants.take(3)) {
          print('   - ${restaurant.name} (${restaurant.province ?? restaurant.city ?? "위치불명"})');
        }
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

  // ===== 즐겨찾기 시스템 =====

  /// 지역별 맛집 리스트 조회 (기존 메서드를 활용해서 확장)
  static Future<List<Restaurant>> getRestaurantsByRegion({
    required String region,
    int limit = 20,
    String? category,
  }) async {
    try {
      if (kDebugMode) {
        print('🍽️ 지역별 맛집 조회 시작: $region');
      }

      String? city;
      String? province;

      // 지역명에 따른 필터링 설정
      if (region == '제주도') {
        province = '제주특별자치도';
      } else if (region == '서울') {
        province = '서울특별시';
      } else if (region == '부산') {
        province = '부산광역시';
      } else if (region == '경주') {
        city = '경주시';
      }

      // 기존 getPopularRestaurants 메서드 활용
      final restaurants = await getPopularRestaurants(
        city: city,
        province: province,
        limit: limit,
      );

      if (kDebugMode) {
        print('✅ 지역별 맛집 조회 완료: ${restaurants.length}개');
      }

      return restaurants;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 지역별 맛집 조회 실패: $e');
      }
      return [];
    }
  }

  /// 사용자의 즐겨찾기 맛집 목록 조회 (서브컬렉션 기반)
  static Future<List<Restaurant>> getFavoriteRestaurants(String userId) async {
    try {
      if (kDebugMode) {
        print('❤️ 즐겨찾기 맛집 조회 시작: $userId');
      }

      // 서브컬렉션에서 직접 조회
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteRestaurantsData')
          .orderBy('savedAt', descending: true) // 최신 추가순
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('📭 즐겨찾기 맛집 없음');
        }
        return [];
      }

      // 서브컬렉션에서 Restaurant 객체 생성
      final restaurants = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Restaurant(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? '',
          address: data['address'] ?? '',
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
          category: data['category'] ?? '',
          phone: data['phone'],
          url: data['url'],
          rating: (data['rating'] as num?)?.toDouble(),
          distance: data['distance'],
          city: data['city'],
          province: data['province'],
          updatedAt: data['savedAt'] != null 
              ? (data['savedAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();

      if (kDebugMode) {
        print('✅ 즐겨찾기 맛집 조회 완료: ${restaurants.length}개');
        for (final restaurant in restaurants) {
          print('   - ${restaurant.name} (저장일: ${restaurant.updatedAt})');
        }
      }

      return restaurants;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 맛집 조회 실패: $e');
      }
      return [];
    }
  }

  /// 즐겨찾기 추가
  static Future<bool> addToFavorites(String restaurantId) async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) {
        if (kDebugMode) {
          print('❌ 즐겨찾기 추가 실패: 로그인 필요');
        }
        return false;
      }

      await UserService.addFavoriteRestaurant(userId, restaurantId);
      
      if (kDebugMode) {
        print('✅ 즐겨찾기 추가 완료: $restaurantId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 추가 실패: $e');
      }
      return false;
    }
  }

  /// 즐겨찾기 제거 (서브컬렉션 방식)
  static Future<bool> removeFromFavorites(String restaurantId) async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) {
        if (kDebugMode) {
          print('❌ 즐겨찾기 제거 실패: 로그인 필요');
        }
        return false;
      }

      // 기존 방식: favoriteRestaurants 배열에서 제거
      await UserService.removeFavoriteRestaurant(userId, restaurantId);
      
      // 서브컬렉션에서도 제거
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteRestaurantsData')
          .doc(restaurantId)
          .delete();
      
      if (kDebugMode) {
        print('✅ 즐겨찾기 제거 완료: $restaurantId (서브컬렉션 포함)');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 제거 실패: $e');
      }
      return false;
    }
  }

  /// 즐겨찾기 여부 확인
  static Future<bool> isFavorite(String restaurantId) async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) return false;

      return await UserService.isFavoriteRestaurant(userId, restaurantId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 확인 실패: $e');
      }
      return false;
    }
  }

  /// 즐겨찾기 토글 (추가/제거)
  static Future<bool> toggleFavorite(String restaurantId) async {
    try {
      final isFav = await isFavorite(restaurantId);
      
      if (isFav) {
        return await removeFromFavorites(restaurantId);
      } else {
        return await addToFavorites(restaurantId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 토글 실패: $e');
      }
      return false;
    }
  }

  /// 식당 데이터와 함께 즐겨찾기 토글 (서브컬렉션 방식)
  static Future<bool> toggleFavoriteWithData(Restaurant restaurant) async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) {
        if (kDebugMode) {
          print('❌ 즐겨찾기 실패: 로그인 필요');
        }
        return false;
      }

      // 현재 즐겨찾기 상태 확인
      final isFav = await UserService.isFavoriteRestaurant(userId, restaurant.id);
      
      if (isFav) {
        // 즐겨찾기에서 제거
        await UserService.removeFavoriteRestaurant(userId, restaurant.id);
        // 서브컬렉션에서도 제거
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('favoriteRestaurantsData')
            .doc(restaurant.id)
            .delete();
        
        if (kDebugMode) {
          print('✅ 즐겨찾기 제거 완료: ${restaurant.name}');
        }
        return false;
      } else {
        // 즐겨찾기에 추가
        await UserService.addFavoriteRestaurant(userId, restaurant.id);
        // 서브컬렉션에 식당 데이터 저장
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('favoriteRestaurantsData')
            .doc(restaurant.id)
            .set({
          'id': restaurant.id,
          'name': restaurant.name,
          'address': restaurant.address,
          'latitude': restaurant.latitude,
          'longitude': restaurant.longitude,
          'category': restaurant.category,
          'phone': restaurant.phone,
          'url': restaurant.url,
          'rating': restaurant.rating,
          'distance': restaurant.distance,
          'city': restaurant.city,
          'province': restaurant.province,
          'savedAt': FieldValue.serverTimestamp(),
          'source': 'kakao_search', // 카카오 검색에서 즐겨찾기로 추가됨
        });
        
        if (kDebugMode) {
          print('✅ 즐겨찾기 추가 완료: ${restaurant.name}');
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 토글 실패: $e');
      }
      return false;
    }
  }
}