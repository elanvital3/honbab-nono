import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_evaluation.dart';
import '../models/meeting.dart';
import 'user_service.dart';

class EvaluationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_evaluations';

  /// 사용자 평가 제출
  static Future<void> submitEvaluation(UserEvaluation evaluation) async {
    try {
      // 중복 평가 방지 - 같은 모임에서 같은 사용자를 이미 평가했는지 확인
      final existingEvaluation = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: evaluation.meetingId)
          .where('evaluatorId', isEqualTo: evaluation.evaluatorId)
          .where('evaluatedUserId', isEqualTo: evaluation.evaluatedUserId)
          .limit(1)
          .get();

      if (existingEvaluation.docs.isNotEmpty) {
        throw Exception('이미 해당 사용자를 평가하셨습니다');
      }

      // 평가 저장
      await _firestore.collection(_collection).add(evaluation.toFirestore());

      // 평가받은 사용자의 평점 업데이트
      await _updateUserRating(evaluation.evaluatedUserId);

      if (kDebugMode) {
        print('✅ 사용자 평가 제출 완료: ${evaluation.evaluatedUserId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 평가 제출 실패: $e');
      }
      rethrow;
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

  /// 특정 모임에서 내가 평가해야 할 사용자 목록 조회
  static Future<List<String>> getPendingEvaluations(String meetingId, String currentUserId) async {
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

      // 이미 평가한 사용자들 조회
      final existingEvaluations = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: meetingId)
          .where('evaluatorId', isEqualTo: currentUserId)
          .get();

      final evaluatedUserIds = existingEvaluations.docs
          .map((doc) => doc.data()['evaluatedUserId'] as String)
          .toSet();

      // 아직 평가하지 않은 사용자들 반환
      return otherParticipants
          .where((userId) => !evaluatedUserIds.contains(userId))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 대기 중인 평가 조회 실패: $e');
      }
      return [];
    }
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
}