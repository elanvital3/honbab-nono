import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/user.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'users';

  // 사용자 생성
  static Future<void> createUser(User user) async {
    try {
      if (kDebugMode) {
        print('📝 사용자 생성 시작:');
        print('  - 사용자 ID: ${user.id}');
        print('  - 사용자 이름: ${user.name}');
        print('  - 카카오 ID: ${user.kakaoId}');
        print('  - 이메일: ${user.email}');
        print('  - Firestore 데이터: ${user.toFirestore()}');
      }
      
      await _firestore.collection(_collection).doc(user.id).set(user.toFirestore());
      
      if (kDebugMode) {
        print('✅ User created successfully: ${user.id}');
        
        // 생성 확인
        final createdUser = await getUser(user.id);
        print('🔍 생성 확인: ${createdUser != null ? "성공 (${createdUser.name})" : "실패"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating user: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error details: ${e.toString()}');
      }
      rethrow;
    }
  }

  // 사용자 가져오기
  static Future<User?> getUser(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user: $e');
      }
      return null;
    }
  }

  // 사용자 실시간 스트림
  static Stream<User?> getUserStream(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    });
  }

  // 사용자 업데이트 (Map)
  static Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(id).update(updates);
      
      if (kDebugMode) {
        print('✅ User updated: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user: $e');
      }
      rethrow;
    }
  }

  // 사용자 업데이트 (User 객체)
  static Future<void> updateUserFromObject(User user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).update(user.toFirestore());
      
      if (kDebugMode) {
        print('✅ User updated: ${user.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user: $e');
      }
      rethrow;
    }
  }

  // 닉네임 중복 체크
  static Future<bool> isNicknameExists(String nickname) async {
    try {
      final user = await getUserByNickname(nickname);
      return user != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking nickname existence: $e');
      }
      return false;
    }
  }

  // 사용자 삭제
  static Future<void> deleteUser(String id) async {
    try {
      if (kDebugMode) {
        print('🗑️ 사용자 삭제 시작: $id');
      }
      
      // 삭제 전 사용자가 존재하는지 확인
      final existingUser = await getUser(id);
      if (kDebugMode) {
        print('🔍 삭제 전 사용자 확인: ${existingUser != null ? "존재함 (${existingUser.name}, 카카오ID: ${existingUser.kakaoId})" : "존재하지 않음"}');
      }
      
      await _firestore.collection(_collection).doc(id).delete();
      
      // 삭제 후 확인
      final deletedUser = await getUser(id);
      if (kDebugMode) {
        print('🔍 삭제 후 확인: ${deletedUser != null ? "아직 존재함 ⚠️" : "완전히 삭제됨 ✅"}');
        print('✅ User deleted: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting user: $e');
      }
      rethrow;
    }
  }

  // 이메일로 사용자 찾기
  static Future<User?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user by email: $e');
      }
      return null;
    }
  }

  // 전화번호로 사용자 찾기
  static Future<User?> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user by phone: $e');
      }
      return null;
    }
  }

  // 카카오 ID로 사용자 찾기
  static Future<User?> getUserByKakaoId(String kakaoId) async {
    try {
      if (kDebugMode) {
        print('🔍 카카오 ID로 사용자 검색 시작: $kakaoId');
      }
      
      final query = await _firestore
          .collection(_collection)
          .where('kakaoId', isEqualTo: kakaoId)
          .limit(1)
          .get();
      
      if (kDebugMode) {
        print('🔍 검색 결과: ${query.docs.length}개 문서 발견');
        if (query.docs.isNotEmpty) {
          print('🔍 발견된 사용자 데이터: ${query.docs.first.data()}');
        }
      }
      
      if (query.docs.isNotEmpty) {
        final user = User.fromFirestore(query.docs.first);
        if (kDebugMode) {
          print('✅ 카카오 ID 검색 성공: ${user.name} (ID: ${user.id})');
        }
        return user;
      }
      
      if (kDebugMode) {
        print('❌ 카카오 ID 검색 결과 없음: $kakaoId');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user by kakao ID: $e');
        print('❌ Error type: ${e.runtimeType}');
      }
      return null;
    }
  }

  // 닉네임으로 사용자 찾기 (중복 체크용)
  static Future<User?> getUserByNickname(String nickname) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('name', isEqualTo: nickname)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user by nickname: $e');
      }
      return null;
    }
  }

  // 현재 사용자가 특정 카카오 ID의 소유자인지 확인
  static Future<bool> isCurrentUserOwnerOfKakaoId(String? kakaoId) async {
    try {
      if (kakaoId == null) return false;
      
      final currentFirebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentFirebaseUser == null) return false;
      
      // 현재 사용자 정보 가져오기
      final currentUser = await getUser(currentFirebaseUser.uid);
      if (currentUser == null) return false;
      
      // 카카오 ID 비교
      final isOwner = currentUser.kakaoId == kakaoId;
      
      if (kDebugMode) {
        print('🔍 카카오 ID 소유권 확인:');
        print('  - 현재 사용자 카카오 ID: ${currentUser.kakaoId}');
        print('  - 확인할 카카오 ID: $kakaoId');
        print('  - 소유권 여부: $isOwner');
      }
      
      return isOwner;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking kakao ID ownership: $e');
      }
      return false;
    }
  }

  // 닉네임과 함께 사용자 생성 (회원가입 완료용)
  static Future<User?> createUserWithNickname({
    required String id,
    required String name,
    String? email,
    String? profileImageUrl,
    String? kakaoId,
  }) async {
    try {
      final user = User(
        id: id,
        name: name,
        email: email,
        profileImageUrl: profileImageUrl,
        kakaoId: kakaoId,
      );
      
      await _firestore.collection(_collection).doc(id).set(user.toFirestore());
      
      if (kDebugMode) {
        print('✅ User created with nickname: ${user.name}');
      }
      
      return user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating user with nickname: $e');
      }
      rethrow;
    }
  }

  // 모임 호스팅 횟수 증가
  static Future<void> incrementHostedMeetings(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'meetingsHosted': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Incremented hosted meetings for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error incrementing hosted meetings: $e');
      }
      rethrow;
    }
  }

  // 모임 참여 횟수 증가
  static Future<void> incrementJoinedMeetings(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'meetingsJoined': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Incremented joined meetings for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error incrementing joined meetings: $e');
      }
      rethrow;
    }
  }

  // 모임 호스팅 횟수 감소
  static Future<void> decrementHostedMeetings(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'meetingsHosted': FieldValue.increment(-1),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Decremented hosted meetings for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error decrementing hosted meetings: $e');
      }
      rethrow;
    }
  }

  // 모임 참여 횟수 감소
  static Future<void> decrementJoinedMeetings(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'meetingsJoined': FieldValue.increment(-1),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Decremented joined meetings for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error decrementing joined meetings: $e');
      }
      rethrow;
    }
  }

  // 즐겨찾는 식당 추가
  static Future<void> addFavoriteRestaurant(String userId, String restaurantId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'favoriteRestaurants': FieldValue.arrayUnion([restaurantId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Added favorite restaurant for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding favorite restaurant: $e');
      }
      rethrow;
    }
  }

  // 즐겨찾는 식당 제거
  static Future<void> removeFavoriteRestaurant(String userId, String restaurantId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'favoriteRestaurants': FieldValue.arrayRemove([restaurantId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Removed favorite restaurant for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing favorite restaurant: $e');
      }
      rethrow;
    }
  }

  /// 사용자가 채팅방에 입장했음을 기록
  static Future<void> enterChatRoom(String userId, String chatRoomId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'currentChatRoom': chatRoomId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ 사용자 채팅방 입장 기록: $userId -> $chatRoomId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅방 입장 기록 실패: $e');
      }
      rethrow;
    }
  }

  /// 사용자가 채팅방에서 나갔음을 기록
  static Future<void> leaveChatRoom(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'currentChatRoom': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ 사용자 채팅방 퇴장 기록: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅방 퇴장 기록 실패: $e');
      }
      rethrow;
    }
  }

  /// 사용자의 현재 채팅방 상태 조회
  static Future<String?> getCurrentChatRoom(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['currentChatRoom'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 현재 채팅방 조회 실패: $e');
      }
      return null;
    }
  }

  /// 사용자의 현재 위치 정보 업데이트
  static Future<void> updateUserLocation(String userId, double latitude, double longitude) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'lastLatitude': latitude,
        'lastLongitude': longitude,
        'lastLocationUpdated': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ 사용자 위치 업데이트: $userId -> ($latitude, $longitude)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 위치 업데이트 실패: $e');
      }
      rethrow;
    }
  }

  /// 반경 내 사용자들의 FCM 토큰 조회 (근처 모임 알림용)
  static Future<List<String>> getNearbyUserTokens({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    String? excludeUserId,
    int maxResults = 100,
  }) async {
    try {
      // Firestore는 지리적 쿼리를 직접 지원하지 않으므로
      // 모든 사용자를 가져와서 클라이언트에서 거리 계산
      final query = await _firestore.collection(_collection)
          .where('lastLatitude', isNull: false)
          .where('lastLongitude', isNull: false)
          .where('fcmToken', isNull: false)
          .limit(500) // 성능을 위해 제한
          .get();
      
      final nearbyTokens = <String>[];
      
      for (final doc in query.docs) {
        final data = doc.data();
        final userId = doc.id;
        
        if (excludeUserId != null && userId == excludeUserId) continue;
        
        final latitude = data['lastLatitude'] as double?;
        final longitude = data['lastLongitude'] as double?;
        final fcmToken = data['fcmToken'] as String?;
        
        if (latitude != null && longitude != null && fcmToken != null) {
          final distance = _calculateDistance(
            centerLatitude, centerLongitude,
            latitude, longitude,
          );
          
          if (distance <= radiusKm) {
            nearbyTokens.add(fcmToken);
            if (nearbyTokens.length >= maxResults) break;
          }
        }
      }
      
      if (kDebugMode) {
        print('🔍 반경 ${radiusKm}km 내 사용자 토큰: ${nearbyTokens.length}개');
      }
      
      return nearbyTokens;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 근처 사용자 토큰 조회 실패: $e');
      }
      return [];
    }
  }

  /// 두 지점 간의 거리 계산 (Haversine 공식)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// 도(degree)를 라디안(radian)으로 변환
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}