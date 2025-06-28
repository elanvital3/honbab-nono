import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meeting.dart';

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

  // 호스트의 모임 목록 가져오기
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
}