import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/restaurant_evaluation.dart';

class RestaurantEvaluationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'restaurant_evaluations';

  /// 식당 평가 제출
  static Future<void> submitRestaurantEvaluation(RestaurantEvaluation evaluation) async {
    try {
      // 중복 평가 방지 - 같은 모임에서 같은 식당을 이미 평가했는지 확인
      final existingEvaluation = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: evaluation.meetingId)
          .where('evaluatorId', isEqualTo: evaluation.evaluatorId)
          .where('restaurantId', isEqualTo: evaluation.restaurantId)
          .limit(1)
          .get();

      if (existingEvaluation.docs.isNotEmpty) {
        throw Exception('이미 해당 식당을 평가하셨습니다');
      }

      // 평가 저장
      await _firestore.collection(_collection).add(evaluation.toFirestore());

      if (kDebugMode) {
        print('✅ 식당 평가 제출 완료: ${evaluation.restaurantName} (${evaluation.rating}점)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 평가 제출 실패: $e');
      }
      rethrow;
    }
  }

  /// 특정 식당의 평가 목록 조회
  static Future<List<RestaurantEvaluation>> getRestaurantEvaluations(String restaurantId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RestaurantEvaluation.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 평가 목록 조회 실패: $e');
      }
      return [];
    }
  }

  /// 특정 식당의 평가 통계 조회
  static Future<Map<String, dynamic>> getRestaurantEvaluationStats(String restaurantId) async {
    try {
      final evaluations = await getRestaurantEvaluations(restaurantId);

      if (evaluations.isEmpty) {
        return {
          'totalEvaluations': 0,
          'averageRating': 0.0,
          'ratingDistribution': <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      // 평균 평점 계산
      double totalRating = 0;
      final ratingDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (final evaluation in evaluations) {
        totalRating += evaluation.rating;
        ratingDistribution[evaluation.rating] = (ratingDistribution[evaluation.rating] ?? 0) + 1;
      }

      final averageRating = totalRating / evaluations.length;

      return {
        'totalEvaluations': evaluations.length,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 평가 통계 조회 실패: $e');
      }
      return {
        'totalEvaluations': 0,
        'averageRating': 0.0,
        'ratingDistribution': <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }
  }

  /// 사용자가 작성한 식당 평가 목록 조회
  static Future<List<RestaurantEvaluation>> getUserRestaurantEvaluations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('evaluatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RestaurantEvaluation.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 식당 평가 목록 조회 실패: $e');
      }
      return [];
    }
  }

  /// 특정 모임에서 사용자가 식당을 평가했는지 확인
  static Future<bool> hasUserEvaluatedRestaurant(String meetingId, String userId, String restaurantId) async {
    try {
      final evaluation = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: meetingId)
          .where('evaluatorId', isEqualTo: userId)
          .where('restaurantId', isEqualTo: restaurantId)
          .limit(1)
          .get();

      return evaluation.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 평가 여부 확인 실패: $e');
      }
      return false;
    }
  }

  /// 회원탈퇴 시 식당 평가 데이터 삭제
  static Future<int> deleteUserRestaurantEvaluations(String userId) async {
    try {
      if (kDebugMode) {
        print('🗑️ 식당 평가 데이터 삭제 시작: $userId');
      }

      final batch = _firestore.batch();
      int deletedCount = 0;

      // 해당 사용자가 작성한 모든 식당 평가 조회 및 삭제
      final evaluations = await _firestore
          .collection(_collection)
          .where('evaluatorId', isEqualTo: userId)
          .get();

      for (final doc in evaluations.docs) {
        batch.delete(doc.reference);
        deletedCount++;
      }

      // 배치 삭제 실행
      await batch.commit();

      if (kDebugMode) {
        print('✅ 식당 평가 데이터 삭제 완료: ${deletedCount}개');
      }

      return deletedCount;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 평가 데이터 삭제 실패: $e');
      }
      rethrow;
    }
  }

  /// 식당별 최신 코멘트 조회 (미리보기용)
  static Future<List<Map<String, dynamic>>> getRestaurantComments(String restaurantId, {int limit = 5}) async {
    try {
      final evaluations = await _firestore
          .collection(_collection)
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return evaluations.docs
          .map((doc) => RestaurantEvaluation.fromFirestore(doc))
          .where((evaluation) => evaluation.comment != null && evaluation.comment!.trim().isNotEmpty)
          .map((evaluation) => {
            'comment': evaluation.comment!,
            'rating': evaluation.rating,
            'createdAt': evaluation.createdAt,
            'evaluatorId': evaluation.evaluatorId, // 필요시 익명화 가능
          })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당 코멘트 조회 실패: $e');
      }
      return [];
    }
  }
}