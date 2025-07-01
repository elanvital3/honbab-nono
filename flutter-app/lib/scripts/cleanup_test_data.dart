import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 테스트 데이터 전체 정리 스크립트
/// 
/// 사용법:
/// 1. 앱에서 이 스크립트를 임포트
/// 2. CleanupTestData.cleanupAll() 호출
/// 
/// ⚠️ 주의: 모든 데이터가 삭제됩니다!
class CleanupTestData {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 모든 테스트 데이터 정리
  static Future<void> cleanupAll() async {
    if (!kDebugMode) {
      print('❌ 프로덕션 환경에서는 실행할 수 없습니다!');
      return;
    }

    try {
      print('🧹 테스트 데이터 정리 시작...');
      
      // 1. Users 컬렉션 정리
      await _cleanupCollection('users', '👤 사용자');
      
      // 2. Meetings 컬렉션 정리  
      await _cleanupCollection('meetings', '🍽️ 모임');
      
      // 3. FCM Tokens 컬렉션 정리
      await _cleanupCollection('fcm_tokens', '🔔 FCM 토큰');
      
      // 4. Chat Rooms 컬렉션 정리 (있다면)
      await _cleanupCollection('chat_rooms', '💬 채팅방');
      
      // 5. Messages 컬렉션 정리 (있다면)
      await _cleanupCollection('messages', '📝 메시지');
      
      print('✅ 모든 테스트 데이터 정리 완료!');
      print('🚀 이제 깔끔한 상태에서 새로 시작할 수 있습니다.');
      
    } catch (e) {
      print('❌ 데이터 정리 실패: $e');
      rethrow;
    }
  }

  /// 특정 컬렉션의 모든 문서 삭제
  static Future<void> _cleanupCollection(String collectionName, String displayName) async {
    try {
      print('🔄 $displayName 데이터 정리 중...');
      
      // 배치 삭제를 위한 쿼리
      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .limit(500) // Firestore 배치 제한
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('ℹ️ $displayName: 삭제할 데이터가 없습니다.');
        return;
      }
      
      // 배치 삭제 실행
      WriteBatch batch = _firestore.batch();
      int deleteCount = 0;
      
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
        deleteCount++;
      }
      
      await batch.commit();
      print('✅ $displayName: ${deleteCount}개 문서 삭제 완료');
      
      // 500개 이상인 경우 재귀적으로 계속 삭제
      if (snapshot.docs.length >= 500) {
        await _cleanupCollection(collectionName, displayName);
      }
      
    } catch (e) {
      print('❌ $displayName 정리 실패: $e');
      // 컬렉션이 존재하지 않는 경우는 무시
      if (!e.toString().contains('not found')) {
        rethrow;
      }
    }
  }

  /// 특정 사용자의 데이터만 삭제 (개발용)
  static Future<void> cleanupUserData(String userId) async {
    if (!kDebugMode) {
      print('❌ 프로덕션 환경에서는 실행할 수 없습니다!');
      return;
    }

    try {
      print('🗑️ 사용자 데이터 삭제 시작: $userId');
      
      // 1. 사용자 문서 삭제
      await _firestore.collection('users').doc(userId).delete();
      print('✅ 사용자 문서 삭제 완료');
      
      // 2. 사용자가 호스트인 모임 삭제
      final hostedMeetings = await _firestore
          .collection('meetings')
          .where('hostId', isEqualTo: userId)
          .get();
      
      WriteBatch batch = _firestore.batch();
      for (var doc in hostedMeetings.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ 호스트 모임 ${hostedMeetings.docs.length}개 삭제 완료');
      
      // 3. 참여한 모임에서 제거
      final participatedMeetings = await _firestore
          .collection('meetings')
          .where('participantIds', arrayContains: userId)
          .get();
      
      batch = _firestore.batch();
      for (var doc in participatedMeetings.docs) {
        batch.update(doc.reference, {
          'participantIds': FieldValue.arrayRemove([userId]),
        });
      }
      await batch.commit();
      print('✅ 참여 모임 ${participatedMeetings.docs.length}개에서 제거 완료');
      
      print('✅ 사용자 데이터 삭제 완료: $userId');
      
    } catch (e) {
      print('❌ 사용자 데이터 삭제 실패: $e');
      rethrow;
    }
  }

  /// 데이터 통계 확인
  static Future<void> showDataStats() async {
    try {
      print('📊 현재 데이터 통계:');
      
      final collections = ['users', 'meetings', 'fcm_tokens', 'chat_rooms'];
      
      for (String collectionName in collections) {
        try {
          final snapshot = await _firestore.collection(collectionName).count().get();
          final count = snapshot.count;
          print('  - $collectionName: $count개');
        } catch (e) {
          print('  - $collectionName: 컬렉션 없음');
        }
      }
      
    } catch (e) {
      print('❌ 통계 조회 실패: $e');
    }
  }

  /// Firebase Auth 사용자도 정리 (선택사항)
  static Future<void> cleanupFirebaseAuth() async {
    if (!kDebugMode) {
      print('❌ 프로덕션 환경에서는 실행할 수 없습니다!');
      return;
    }

    try {
      print('🔐 Firebase Auth 정리...');
      
      // 현재 사용자 로그아웃
      await FirebaseAuth.instance.signOut();
      
      print('✅ Firebase Auth 로그아웃 완료');
      print('ℹ️ 다음 로그인 시 새로운 UID가 생성됩니다.');
      
    } catch (e) {
      print('❌ Firebase Auth 정리 실패: $e');
    }
  }
}