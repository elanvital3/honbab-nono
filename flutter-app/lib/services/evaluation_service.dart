import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_evaluation.dart';
import '../models/meeting.dart';
import 'user_service.dart';
import 'meeting_service.dart';

class EvaluationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_evaluations';

  /// 사용자 평가 제출 (1대1 평가 시스템)
  static Future<void> submitEvaluation(UserEvaluation evaluation) async {
    try {
      // 중복 평가 방지 - 해당 사용자를 평생 한 번만 평가 가능
      final existingEvaluation = await _firestore
          .collection(_collection)
          .where('evaluatorId', isEqualTo: evaluation.evaluatorId)
          .where('evaluatedUserId', isEqualTo: evaluation.evaluatedUserId)
          .limit(1)
          .get();

      if (existingEvaluation.docs.isNotEmpty) {
        // 기존 평가가 있으면 업데이트
        final docId = existingEvaluation.docs.first.id;
        await _firestore.collection(_collection).doc(docId).update(evaluation.toFirestore());
        
        if (kDebugMode) {
          print('✅ 기존 평가 업데이트 완료: ${evaluation.evaluatedUserId}');
        }
      } else {
        // 새로운 평가 저장
        await _firestore.collection(_collection).add(evaluation.toFirestore());
        
        if (kDebugMode) {
          print('✅ 신규 평가 저장 완료: ${evaluation.evaluatedUserId}');
        }
      }

      // 평가받은 사용자의 평점 업데이트
      await _updateUserRating(evaluation.evaluatedUserId);

      // 모든 평가가 완료되었는지 확인
      await _checkAndCompleteMeetingIfAllEvaluationsFinished(evaluation.meetingId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 평가 제출 실패: $e');
      }
      rethrow;
    }
  }

  /// 기존 평가 조회 (수정 모드용)
  static Future<UserEvaluation?> getExistingEvaluation(String evaluatorId, String evaluatedUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('evaluatorId', isEqualTo: evaluatorId)
          .where('evaluatedUserId', isEqualTo: evaluatedUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserEvaluation.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 기존 평가 조회 실패: $e');
      }
      return null;
    }
  }

  /// 평가받은 사용자의 평점 재계산 및 업데이트
  static Future<void> _updateUserRating(String userId) async {
    try {
      // 해당 사용자에 대한 모든 평가 조회
      final evaluations = await _firestore
          .collection(_collection)
          .where('evaluatedUserId', isEqualTo: userId)
          .get();

      if (evaluations.docs.isEmpty) {
        return; // 평가가 없으면 기본값 유지
      }

      // 평균 평점 계산
      double totalRating = 0;
      int evaluationCount = evaluations.docs.length;

      for (final doc in evaluations.docs) {
        final evaluation = UserEvaluation.fromFirestore(doc);
        totalRating += evaluation.averageRating;
      }

      final averageRating = totalRating / evaluationCount;

      // 사용자 평점 업데이트
      await UserService.updateUser(userId, {
        'rating': averageRating,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('✅ 사용자 평점 업데이트: $userId -> ${averageRating.toStringAsFixed(1)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 평점 업데이트 실패: $e');
      }
      rethrow;
    }
  }

  /// 특정 모임에서 내가 평가할 수 있는 사용자 목록 조회 (1대1 평가 시스템)
  static Future<List<Map<String, dynamic>>> getPendingEvaluations(String meetingId, String currentUserId) async {
    try {
      // 모임 정보 조회
      final meetingDoc = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingId)
          .get();

      if (!meetingDoc.exists) {
        return [];
      }

      final meeting = Meeting.fromFirestore(meetingDoc);
      
      // 자신을 제외한 참여자 목록
      final otherParticipants = meeting.participantIds
          .where((id) => id != currentUserId)
          .toList();

      // 결과 리스트 (userId와 기존 평가 여부 포함)
      final result = <Map<String, dynamic>>[];

      for (final userId in otherParticipants) {
        // 해당 사용자에 대한 기존 평가 조회
        final existingEvaluation = await getExistingEvaluation(currentUserId, userId);
        
        result.add({
          'userId': userId,
          'hasExistingEvaluation': existingEvaluation != null,
          'existingEvaluation': existingEvaluation,
        });
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 대상자 조회 실패: $e');
      }
      return [];
    }
  }

  /// 레거시 메소드 호환성 유지 (기존 코드에서 사용)
  static Future<List<String>> getPendingEvaluationUserIds(String meetingId, String currentUserId) async {
    final pendingEvaluations = await getPendingEvaluations(meetingId, currentUserId);
    return pendingEvaluations.map((item) => item['userId'] as String).toList();
  }

  /// 사용자가 받은 평가 목록 조회
  static Future<List<UserEvaluation>> getUserEvaluations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('evaluatedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserEvaluation.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 평가 목록 조회 실패: $e');
      }
      return [];
    }
  }

  /// 사용자가 받은 코멘트만 조회 (익명화)
  static Future<List<Map<String, dynamic>>> getUserComments(String userId) async {
    try {
      final evaluations = await getUserEvaluations(userId);
      
      // 코멘트가 있는 평가만 필터링하고 익명화
      return evaluations
          .where((evaluation) => evaluation.comment != null && evaluation.comment!.trim().isNotEmpty)
          .map((evaluation) => {
            'comment': evaluation.comment!,
            'meetingLocation': evaluation.meetingLocation ?? '알 수 없는 장소',
            'meetingRestaurant': evaluation.meetingRestaurant,
            'meetingDateTime': evaluation.meetingDateTime,
            'createdAt': evaluation.createdAt,
            'averageRating': evaluation.averageRating,
          })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 코멘트 조회 실패: $e');
      }
      return [];
    }
  }

  /// 사용자의 평가 통계 조회
  static Future<Map<String, dynamic>> getUserEvaluationStats(String userId) async {
    try {
      final evaluations = await getUserEvaluations(userId);

      if (evaluations.isEmpty) {
        return {
          'totalEvaluations': 0,
          'averageRating': 0.0,
          'punctualityAverage': 0.0,
          'friendlinessAverage': 0.0,
          'communicationAverage': 0.0,
        };
      }

      double punctualitySum = 0;
      double friendlinessSum = 0;
      double communicationSum = 0;

      for (final evaluation in evaluations) {
        punctualitySum += evaluation.punctualityRating;
        friendlinessSum += evaluation.friendlinessRating;
        communicationSum += evaluation.communicationRating;
      }

      final count = evaluations.length;

      return {
        'totalEvaluations': count,
        'averageRating': (punctualitySum + friendlinessSum + communicationSum) / (count * 3),
        'punctualityAverage': punctualitySum / count,
        'friendlinessAverage': friendlinessSum / count,
        'communicationAverage': communicationSum / count,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 평가 통계 조회 실패: $e');
      }
      return {
        'totalEvaluations': 0,
        'averageRating': 0.0,
        'punctualityAverage': 0.0,
        'friendlinessAverage': 0.0,
        'communicationAverage': 0.0,
      };
    }
  }

  /// 특정 모임에 대한 평가 완료율 조회
  static Future<Map<String, dynamic>> getMeetingEvaluationProgress(String meetingId) async {
    try {
      // 모임 정보 조회
      final meetingDoc = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingId)
          .get();

      if (!meetingDoc.exists) {
        return {'totalRequired': 0, 'completed': 0, 'percentage': 0.0};
      }

      final meeting = Meeting.fromFirestore(meetingDoc);
      final participantCount = meeting.participantIds.length;
      
      // 상호 평가이므로 총 필요한 평가 수는 n * (n-1)
      final totalRequired = participantCount * (participantCount - 1);

      // 완료된 평가 수 조회
      final completedEvaluations = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      final completed = completedEvaluations.docs.length;
      final percentage = totalRequired > 0 ? (completed / totalRequired) * 100 : 0.0;

      return {
        'totalRequired': totalRequired,
        'completed': completed,
        'percentage': percentage,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 평가 진행률 조회 실패: $e');
      }
      return {'totalRequired': 0, 'completed': 0, 'percentage': 0.0};
    }
  }

  /// 회원탈퇴 시 평가 데이터 삭제 및 관련 사용자 평점 재계산
  static Future<Set<String>> deleteUserEvaluations(String userId) async {
    try {
      if (kDebugMode) {
        print('🗑️ 평가 데이터 삭제 시작: $userId');
      }

      final batch = _firestore.batch();
      final affectedUsers = <String>{};

      // 1. 해당 사용자가 평가한 모든 기록 조회 및 삭제
      final evaluationsGiven = await _firestore
          .collection(_collection)
          .where('evaluatorId', isEqualTo: userId)
          .get();

      for (final doc in evaluationsGiven.docs) {
        final evaluation = UserEvaluation.fromFirestore(doc);
        affectedUsers.add(evaluation.evaluatedUserId); // 평점 재계산이 필요한 사용자
        batch.delete(doc.reference);
      }

      // 2. 해당 사용자가 평가받은 모든 기록 조회 및 삭제
      final evaluationsReceived = await _firestore
          .collection(_collection)
          .where('evaluatedUserId', isEqualTo: userId)
          .get();

      for (final doc in evaluationsReceived.docs) {
        batch.delete(doc.reference);
      }

      // 3. 배치 삭제 실행
      await batch.commit();

      if (kDebugMode) {
        print('✅ 평가 데이터 삭제 완료:');
        print('   - 삭제한 평가 수: ${evaluationsGiven.docs.length + evaluationsReceived.docs.length}개');
        print('   - 재계산 필요한 사용자: ${affectedUsers.length}명');
      }

      // 4. 영향받은 사용자들의 평점 재계산
      for (final affectedUserId in affectedUsers) {
        try {
          await _updateUserRating(affectedUserId);
          if (kDebugMode) {
            print('✅ 평점 재계산 완료: $affectedUserId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 평점 재계산 실패: $affectedUserId - $e');
          }
          // 개별 재계산 실패는 전체 탈퇴를 방해하지 않음
        }
      }

      return affectedUsers;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 데이터 삭제 실패: $e');
      }
      rethrow;
    }
  }

  /// 모든 평가가 완료되었는지 확인하고, 완료되면 모임을 최종 완료 상태로 변경
  static Future<void> _checkAndCompleteMeetingIfAllEvaluationsFinished(String meetingId) async {
    try {
      // 모임 정보 조회
      final meetingDoc = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingId)
          .get();

      if (!meetingDoc.exists) {
        return;
      }

      final meeting = Meeting.fromFirestore(meetingDoc);
      final participantCount = meeting.participantIds.length;
      
      // 상호 평가이므로 총 필요한 평가 수는 n * (n-1)
      final totalRequired = participantCount * (participantCount - 1);

      // 완료된 평가 수 조회
      final completedEvaluations = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      final completed = completedEvaluations.docs.length;

      if (kDebugMode) {
        print('📊 모임 평가 진행률 확인: $meetingId');
        print('   - 필요한 평가 수: $totalRequired');
        print('   - 완료된 평가 수: $completed');
      }

      // 모든 평가가 완료되었으면 모임을 최종 완료 상태로 변경
      if (completed >= totalRequired && totalRequired > 0) {
        // 현재 채팅방 설정 유지 (평가 시작 시 설정된 값)
        final currentMeeting = Meeting.fromFirestore(meetingDoc);
        bool keepChatActive = currentMeeting.chatActive;
        
        await MeetingService.completeMeeting(meetingId, keepChatActive: keepChatActive);
        
        if (kDebugMode) {
          print('🎉 모든 평가 완료! 모임 최종 완료 처리: $meetingId');
          print('   - 채팅방 유지: $keepChatActive');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 평가 완료 확인 실패: $e');
      }
      // 에러 시에도 평가 제출은 계속 진행
    }
  }
}