import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meeting.dart';
import 'notification_service.dart';
import 'user_service.dart';

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
      
      // 근처 사용자들에게 새 모임 생성 알림 발송
      try {
        final createdMeeting = meeting.copyWith(id: docRef.id);
        await NotificationService().notifyNearbyUsersOfNewMeeting(createdMeeting);
        if (kDebugMode) {
          print('✅ 근처 사용자들에게 새 모임 알림 발송 완료');
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('⚠️ 근처 모임 알림 발송 실패: $notificationError');
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
      // 모임 정보를 먼저 가져와서 호스트 정보 확인
      final meetingDoc = await _firestore.collection(_collection).doc(id).get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }
      
      final meeting = Meeting.fromFirestore(meetingDoc);
      
      // 모임 삭제
      await _firestore.collection(_collection).doc(id).delete();
      
      // 호스트의 주최한 모임 수 감소
      try {
        await UserService.decrementHostedMeetings(meeting.hostId);
        if (kDebugMode) {
          print('✅ 호스트 통계 감소 완료: ${meeting.hostId}');
        }
      } catch (statsError) {
        if (kDebugMode) {
          print('⚠️ 호스트 통계 감소 실패: $statsError');
        }
        // 통계 업데이트 실패는 모임 삭제를 방해하지 않음
      }
      
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

  // 마이그레이션 함수 제거 - 이제 UID만 사용하므로 불필요

  // 모임 신청
  static Future<void> applyToMeeting(String meetingId, String userId) async {
    try {
      final meetingRef = _firestore.collection(_collection).doc(meetingId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        final meeting = Meeting.fromFirestore(snapshot);
        
        // 이미 신청했거나 참여중인지 확인
        bool alreadyApplied = meeting.pendingApplicantIds.contains(userId);
        bool alreadyJoined = meeting.participantIds.contains(userId);
        
        if (alreadyApplied) {
          throw Exception('Already applied to this meeting');
        }
        
        if (alreadyJoined) {
          throw Exception('Already joined this meeting');
        }
        
        if (meeting.hostId == userId) {
          throw Exception('Cannot apply to your own meeting');
        }
        
        if (meeting.currentParticipants >= meeting.maxParticipants) {
          throw Exception('Meeting is full');
        }
        
        // 신청자 목록에 추가
        final updatedApplicants = [...meeting.pendingApplicantIds, userId];
        
        transaction.update(meetingRef, {
          'pendingApplicantIds': updatedApplicants,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        
        if (kDebugMode) {
          print('✅ 모임 신청 완료: $meetingId');
          print('  - 신청자 UID: $userId');
          print('  - 전체 신청자 수: ${updatedApplicants.length}');
        }
      });
      
      // 호스트에게 신청 알림 발송
      try {
        final meeting = await getMeeting(meetingId);
        if (meeting != null) {
          // 신청자 실제 닉네임 가져오기
          final applicantUser = await UserService.getUser(userId);
          final applicantName = applicantUser?.name ?? 'User-${userId.substring(0, 8)}';
          
          // 호스트에게 FCM 알림 발송
          await NotificationService().notifyMeetingApplication(
            meeting: meeting,
            applicantUserId: userId,
            applicantName: applicantName,
          );
          
          if (kDebugMode) {
            print('✅ 모임 신청 FCM 알림 처리 완료');
          }
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('⚠️ 모임 신청 알림 처리 실패: $notificationError');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error applying to meeting: $e');
      }
      rethrow;
    }
  }

  // 모임 신청 승인
  static Future<void> approveMeetingApplication(String meetingId, String applicantId) async {
    try {
      final meetingRef = _firestore.collection(_collection).doc(meetingId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        final meeting = Meeting.fromFirestore(snapshot);
        
        // 신청자가 실제로 신청했는지 확인
        if (!meeting.pendingApplicantIds.contains(applicantId)) {
          throw Exception('User has not applied to this meeting');
        }
        
        // 이미 참여중인지 확인
        if (meeting.participantIds.contains(applicantId)) {
          throw Exception('User is already a participant');
        }
        
        // 정원 확인
        if (meeting.currentParticipants >= meeting.maxParticipants) {
          throw Exception('Meeting is full');
        }
        
        // 신청자를 참여자로 이동
        final updatedApplicants = meeting.pendingApplicantIds.where((id) => id != applicantId).toList();
        final updatedParticipants = [...meeting.participantIds, applicantId];
        
        transaction.update(meetingRef, {
          'pendingApplicantIds': updatedApplicants,
          'participantIds': updatedParticipants,
          'currentParticipants': updatedParticipants.length,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        
        if (kDebugMode) {
          print('✅ 모임 신청 승인 완료: $meetingId');
          print('  - 승인된 사용자: $applicantId');
          print('  - 전체 참여자 수: ${updatedParticipants.length}');
        }
      });
      
      // 신청자에게 승인 알림 발송 & 사용자 통계 업데이트
      try {
        final meeting = await getMeeting(meetingId);
        if (meeting != null) {
          // 사용자 참여 모임 수 증가
          await UserService.incrementJoinedMeetings(applicantId);
          
          // 신청자에게 승인 알림 발송
          final applicantUser = await UserService.getUser(applicantId);
          final applicantName = applicantUser?.name ?? 'User-${applicantId.substring(0, 8)}';
          
          await NotificationService().notifyMeetingApproval(
            meeting: meeting,
            applicantUserId: applicantId,
            applicantName: applicantName,
          );
          
          if (kDebugMode) {
            print('✅ 모임 승인 알림 및 통계 처리 완료');
          }
        }
      } catch (postProcessError) {
        if (kDebugMode) {
          print('⚠️ 모임 승인 후처리 실패: $postProcessError');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error approving meeting application: $e');
      }
      rethrow;
    }
  }

  // 모임 신청 거절
  static Future<void> rejectMeetingApplication(String meetingId, String applicantId) async {
    try {
      final meetingRef = _firestore.collection(_collection).doc(meetingId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        final meeting = Meeting.fromFirestore(snapshot);
        
        // 신청자가 실제로 신청했는지 확인
        if (!meeting.pendingApplicantIds.contains(applicantId)) {
          throw Exception('User has not applied to this meeting');
        }
        
        // 신청자를 목록에서 제거
        final updatedApplicants = meeting.pendingApplicantIds.where((id) => id != applicantId).toList();
        
        transaction.update(meetingRef, {
          'pendingApplicantIds': updatedApplicants,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        
        if (kDebugMode) {
          print('✅ 모임 신청 거절 완료: $meetingId');
          print('  - 거절된 사용자: $applicantId');
        }
      });
      
      // 신청자에게 거절 알림 발송
      try {
        final meeting = await getMeeting(meetingId);
        if (meeting != null) {
          final applicantUser = await UserService.getUser(applicantId);
          final applicantName = applicantUser?.name ?? 'User-${applicantId.substring(0, 8)}';
          
          await NotificationService().notifyMeetingRejection(
            meeting: meeting,
            applicantUserId: applicantId,
            applicantName: applicantName,
          );
          
          if (kDebugMode) {
            print('✅ 모임 거절 알림 처리 완료');
          }
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('⚠️ 모임 거절 알림 처리 실패: $notificationError');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error rejecting meeting application: $e');
      }
      rethrow;
    }
  }

  // 기존 모임 참여 (직접 참여 - 호환성 유지)
  static Future<void> joinMeeting(String meetingId, String userId) async {
    try {
      final meetingRef = _firestore.collection(_collection).doc(meetingId);
      
      // 카카오 ID 조회 로직 제거 - 이제 UID만 사용
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        final meeting = Meeting.fromFirestore(snapshot);
        
        // UID로 이미 참여했는지 확인
        bool alreadyJoined = meeting.participantIds.contains(userId);
        
        if (alreadyJoined) {
          throw Exception('Already joined this meeting');
        }
        
        if (meeting.currentParticipants >= meeting.maxParticipants) {
          throw Exception('Meeting is full');
        }
        
        // UID 추가 만 처리
        final updatedParticipants = [...meeting.participantIds, userId];
        
        transaction.update(meetingRef, {
          'participantIds': updatedParticipants,
          'currentParticipants': updatedParticipants.length,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        
        if (kDebugMode) {
          print('✅ 모임 참여: $meetingId');
          print('  - UID: $userId');
          print('  - 전체 참여자 수: ${updatedParticipants.length}');
        }
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
          
          // 참여자 실제 닉네임 가져오기
          final joinerUser = await UserService.getUser(userId);
          final joinerName = joinerUser?.name ?? 'User-${userId.substring(0, 8)}';
          
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
      Meeting? originalMeeting;
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(meetingRef);
        
        if (!snapshot.exists) {
          throw Exception('Meeting not found');
        }
        
        originalMeeting = Meeting.fromFirestore(snapshot);
        
        if (!originalMeeting!.participantIds.contains(userId)) {
          throw Exception('Not a participant of this meeting');
        }
        
        final updatedParticipants = originalMeeting!.participantIds.where((id) => id != userId).toList();
        
        transaction.update(meetingRef, {
          'participantIds': updatedParticipants,
          'currentParticipants': updatedParticipants.length,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
      
      if (kDebugMode) {
        print('✅ Left meeting: $meetingId');
        print('  - 탈퇴한 사용자: $userId');
        print('  - 남은 참여자 수: ${originalMeeting!.participantIds.length - 1}');
      }
      
      // 탈퇴한 사용자의 참여 모임 수 감소
      try {
        await UserService.decrementJoinedMeetings(userId);
        if (kDebugMode) {
          print('✅ 사용자 참여 통계 감소 완료: $userId');
        }
      } catch (statsError) {
        if (kDebugMode) {
          print('⚠️ 사용자 참여 통계 감소 실패: $statsError');
        }
        // 통계 업데이트 실패는 탈퇴를 방해하지 않음
      }
      
      // 모임 탈퇴 후 알림 처리 (남은 참여자가 있을 때만)
      if (originalMeeting!.participantIds.length > 1) {
        try {
          // 탈퇴한 사용자 실제 닉네임 가져오기
          final leaverUser = await UserService.getUser(userId);
          final leaverName = leaverUser?.name ?? 'User-${userId.substring(0, 8)}';
          
          // 남은 참여자들에게 FCM 알림 발송 (탈퇴한 본인 제외)
          await NotificationService().notifyMeetingLeave(
            meeting: originalMeeting!,
            leaverUserId: userId,
            leaverName: leaverName,
          );
          
          if (kDebugMode) {
            print('✅ 모임 탈퇴 FCM 알림 처리 완료');
          }
        } catch (notificationError) {
          if (kDebugMode) {
            print('⚠️ 모임 탈퇴 알림 처리 실패: $notificationError');
          }
          // 알림 실패는 탈퇴를 방해하지 않음
        }
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