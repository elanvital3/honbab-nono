import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meeting.dart';
import 'notification_service.dart';

class MeetingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'meetings';

  // 모임 생성
  static Future<String> createMeeting(Meeting meeting) async {
    try {
      final docRef = await _firestore.collection(_collection).add(meeting.toFirestore());
      
      if (kDebugMode) {
        print('✅ Meeting created: ${docRef.id}');
      }
      
      // 새 모임 생성 알림 발송
      try {
        final createdMeeting = meeting.copyWith(id: docRef.id);
        await NotificationService().showNewMeetingNotification(createdMeeting);
        if (kDebugMode) {
          print('✅ 새 모임 알림 발송 완료');
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('⚠️ 새 모임 알림 발송 실패: $notificationError');
        }
        // 알림 실패는 모임 생성을 방해하지 않음
      }
      
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating meeting: $e');
      }
      rethrow;
    }
  }

  // 모든 모임 가져오기 (실시간 스트림)
  static Stream<List<Meeting>> getMeetingsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Meeting.fromFirestore(doc))
          .toList();
    });
  }

  // 특정 모임 가져오기
  static Future<Meeting?> getMeeting(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      
      if (doc.exists) {
        return Meeting.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting meeting: $e');
      }
      return null;
    }
  }

  // 모임 업데이트
  static Future<void> updateMeeting(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(id).update(updates);
      
      if (kDebugMode) {
        print('✅ Meeting updated: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating meeting: $e');
      }
      rethrow;
    }
  }

  // 모임 전체 업데이트 (Meeting 객체)
  static Future<void> updateMeetingFromModel(Meeting meeting) async {
    try {
      await _firestore.collection(_collection).doc(meeting.id).update(meeting.toFirestore());
      
      if (kDebugMode) {
        print('✅ Meeting updated: ${meeting.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating meeting: $e');
      }
      rethrow;
    }
  }

  // 모임 완료 (호스트만)
  static Future<void> completeMeeting(String meetingId) async {
    try {
      await _firestore.collection(_collection).doc(meetingId).update({
        'status': 'completed',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      if (kDebugMode) {
        print('✅ Meeting completed: $meetingId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error completing meeting: $e');
      }
      rethrow;
    }
  }

  // 모임 삭제
  static Future<void> deleteMeeting(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      
      if (kDebugMode) {
        print('✅ Meeting deleted: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting meeting: $e');
      }
      rethrow;
    }
  }

  // 기존 모임 데이터에 hostKakaoId 마이그레이션
  static Future<void> migrateMeetingsWithHostKakaoId() async {
    try {
      if (kDebugMode) {
        print('🔄 모임 데이터 마이그레이션 시작...');
      }

      // hostKakaoId가 없는 모임들 찾기
      final query = await _firestore
          .collection(_collection)
          .where('hostKakaoId', isNull: true)
          .get();

      if (query.docs.isEmpty) {
        if (kDebugMode) {
          print('✅ 마이그레이션할 모임이 없음');
        }
        return;
      }

      if (kDebugMode) {
        print('🔍 마이그레이션 대상 모임: ${query.docs.length}개');
      }

      int successCount = 0;
      int failCount = 0;

      for (final doc in query.docs) {
        try {
          final meetingData = doc.data();
          final hostId = meetingData['hostId'] as String?;
          
          if (hostId == null) continue;

          // 호스트의 카카오 ID 찾기
          final hostDoc = await _firestore.collection('users').doc(hostId).get();
          if (!hostDoc.exists) {
            if (kDebugMode) {
              print('⚠️ 호스트 정보 없음: $hostId');
            }
            failCount++;
            continue;
          }

          final hostData = hostDoc.data() as Map<String, dynamic>;
          final hostKakaoId = hostData['kakaoId'] as String?;
          
          if (hostKakaoId == null) {
            if (kDebugMode) {
              print('⚠️ 호스트 카카오 ID 없음: $hostId');
            }
            failCount++;
            continue;
          }

          // 모임 문서에 hostKakaoId 추가
          await doc.reference.update({
            'hostKakaoId': hostKakaoId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

          successCount++;
          
          if (kDebugMode) {
            print('✅ 마이그레이션 완료: ${doc.id} -> $hostKakaoId');
          }

        } catch (e) {
          if (kDebugMode) {
            print('❌ 마이그레이션 실패: ${doc.id} - $e');
          }
          failCount++;
        }
      }

      if (kDebugMode) {
        print('🎉 마이그레이션 완료: 성공 $successCount개, 실패 $failCount개');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ 마이그레이션 실패: $e');
      }
    }
  }

  // 모임 참여
  static Future<void> joinMeeting(String meetingId, String userId) async {
    try {
      final meetingRef = _firestore.collection(_collection).doc(meetingId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        final meeting = Meeting.fromFirestore(snapshot);
        
        if (meeting.participantIds.contains(userId)) {
          throw Exception('Already joined this meeting');
        }
        
        if (meeting.currentParticipants >= meeting.maxParticipants) {
          throw Exception('Meeting is full');
        }
        
        final updatedParticipants = [...meeting.participantIds, userId];
        
        transaction.update(meetingRef, {
          'participantIds': updatedParticipants,
          'currentParticipants': updatedParticipants.length,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
      
      if (kDebugMode) {
        print('✅ Joined meeting: $meetingId');
      }
      
      // 모임 참여 후 처리
      try {
        final meeting = await getMeeting(meetingId);
        if (meeting != null) {
          // 리마인더 알림 예약
          await NotificationService().scheduleMeetingReminder(meeting);
          
          // 참여자 이름 가져오기 (간단한 예시로 userId 사용)
          final joinerName = 'User-${userId.substring(0, 8)}';
          
          // 모든 참여자에게 FCM 알림 발송 (참여한 본인 제외)
          await NotificationService().notifyMeetingParticipation(
            meeting: meeting,
            joinerUserId: userId,
            joinerName: joinerName,
          );
          
          if (kDebugMode) {
            print('✅ 모임 참여 FCM 알림 처리 완료');
          }
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('⚠️ 모임 참여 알림 처리 실패: $notificationError');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error joining meeting: $e');
      }
      rethrow;
    }
  }

  // 모임 탈퇴
  static Future<void> leaveMeeting(String meetingId, String userId) async {
    try {
      final meetingRef = _firestore.collection(_collection).doc(meetingId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        final meeting = Meeting.fromFirestore(snapshot);
        
        if (!meeting.participantIds.contains(userId)) {
          throw Exception('Not a participant of this meeting');
        }
        
        final updatedParticipants = meeting.participantIds.where((id) => id != userId).toList();
        
        transaction.update(meetingRef, {
          'participantIds': updatedParticipants,
          'currentParticipants': updatedParticipants.length,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
      
      if (kDebugMode) {
        print('✅ Left meeting: $meetingId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error leaving meeting: $e');
      }
      rethrow;
    }
  }

  // 사용자의 모임 목록 가져오기
  static Stream<List<Meeting>> getUserMeetingsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('participantIds', arrayContains: userId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Meeting.fromFirestore(doc))
          .toList();
    });
  }

  // 호스트의 모임 목록 가져오기 (스트림)
  static Stream<List<Meeting>> getHostedMeetingsStream(String hostId) {
    return _firestore
        .collection(_collection)
        .where('hostId', isEqualTo: hostId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Meeting.fromFirestore(doc))
          .toList();
    });
  }

  // 호스트의 모임 목록 가져오기 (Future)
  static Future<List<Meeting>> getMeetingsByHost(String hostId) async {
    try {
      if (kDebugMode) {
        print('🔍 MeetingService.getMeetingsByHost 호출: $hostId');
      }
      
      // 인덱스 문제를 피하기 위해 orderBy 제거하고 클라이언트에서 정렬
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostId', isEqualTo: hostId)
          .get();

      if (kDebugMode) {
        print('📊 Firebase 쿼리 결과: ${snapshot.docs.length}개 문서');
      }

      final meetings = snapshot.docs
          .map((doc) => Meeting.fromFirestore(doc))
          .toList();
      
      // 클라이언트에서 날짜순 정렬 (최신순)
      meetings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      // 최대 10개까지만
      if (meetings.length > 10) {
        return meetings.take(10).toList();
      }
      
      if (kDebugMode) {
        print('✅ 최종 반환할 모임 수: ${meetings.length}');
      }
      
      return meetings;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting meetings by host: $e');
      }
      return [];
    }
  }
}