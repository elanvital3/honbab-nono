import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../models/deletion_history.dart';
import '../models/user.dart';

/// 회원탈퇴 이력 관리 서비스
/// 개인정보는 해시화하여 저장하고, 재가입 제한을 관리
class DeletionHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'deletion_history';
  static const String _salt = 'honbab_nono_deletion_salt_2025';

  /// 회원탈퇴 시 이력 저장
  static Future<void> saveDeletionHistory({
    required User user,
    required String deletionReason,
  }) async {
    try {
      // 기존 탈퇴 횟수 조회
      final existingCount = await _getDeletionCount(user.kakaoId, user.email);
      
      // 사용자 행동 점수 계산
      final behaviorScore = _calculateBehaviorScore(user);
      
      // 탈퇴 이력 생성
      final deletionHistory = DeletionHistory(
        id: '', // Firestore에서 자동 생성
        hashedKakaoId: user.kakaoId != null ? _hashString(user.kakaoId!) : '',
        hashedEmail: user.email != null ? _hashString(user.email!) : null,
        deletionReason: deletionReason,
        deletionCount: existingCount + 1,
        deletedAt: DateTime.now(),
        hashedLastNickname: _hashString(user.name),
        behaviorScore: behaviorScore,
        reportCount: 0, // TODO: 실제 신고 데이터와 연동
        meetingsHosted: user.meetingsHosted,
        meetingsJoined: user.meetingsJoined,
        averageRating: user.rating,
        violations: [], // TODO: 실제 위반 기록과 연동
        metadata: DeletionMetadata(
          reactivationAllowedAt: null, // 자동 계산
          permanentBan: false,
          adminNotes: null,
          extra: {
            'deletedAt': DateTime.now().toIso8601String(),
            'userName': user.name,
            'userEmail': user.email,
          },
        ),
      );

      // Firestore에 저장
      await _firestore.collection(_collection).add(deletionHistory.toFirestore());

      if (kDebugMode) {
        print('✅ 탈퇴 이력 저장 완료:');
        print('   - 사용자: ${user.name}');
        print('   - 탈퇴 횟수: ${deletionHistory.deletionCount}');
        print('   - 행동 점수: ${behaviorScore.toStringAsFixed(1)}');
        print('   - 사용자 등급: ${deletionHistory.userGrade}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 탈퇴 이력 저장 실패: $e');
      }
      rethrow;
    }
  }

  /// 재가입 가능 여부 확인
  static Future<ReactivationStatus> checkReactivationStatus({
    required String? kakaoId,
    required String? email,
  }) async {
    try {
      if (kakaoId == null && email == null) {
        return const ReactivationStatus(
          allowed: true,
          waitDays: 0,
          reason: '재가입이 가능합니다.',
        );
      }

      // 가장 최근 탈퇴 이력 조회
      final latestHistory = await _getLatestDeletionHistory(kakaoId, email);
      
      if (latestHistory == null) {
        return const ReactivationStatus(
          allowed: true,
          waitDays: 0,
          reason: '재가입이 가능합니다.',
        );
      }

      // 재가입 상태 반환
      return latestHistory.reactivationStatus;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 재가입 상태 확인 실패: $e');
      }
      // 오류 시 재가입 허용 (안전한 기본값)
      return const ReactivationStatus(
        allowed: true,
        waitDays: 0,
        reason: '재가입이 가능합니다.',
      );
    }
  }

  /// 관리자용: 사용자 탈퇴 이력 조회
  static Future<List<DeletionHistory>> getUserDeletionHistory({
    required String? kakaoId,
    required String? email,
  }) async {
    try {
      if (kakaoId == null && email == null) {
        return [];
      }

      Query query = _firestore.collection(_collection);
      
      if (kakaoId != null) {
        query = query.where('hashedKakaoId', isEqualTo: _hashString(kakaoId));
      } else if (email != null) {
        query = query.where('hashedEmail', isEqualTo: _hashString(email));
      }

      final snapshot = await query.orderBy('deletedAt', descending: true).get();
      
      return snapshot.docs.map((doc) => DeletionHistory.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 탈퇴 이력 조회 실패: $e');
      }
      return [];
    }
  }

  /// 관리자용: 영구 차단 설정
  static Future<void> setPermanentBan({
    required String? kakaoId,
    required String? email,
    required String reason,
    String? adminNotes,
  }) async {
    try {
      final latestHistory = await _getLatestDeletionHistory(kakaoId, email);
      
      if (latestHistory == null) {
        throw Exception('해당 사용자의 탈퇴 이력을 찾을 수 없습니다.');
      }

      // 메타데이터 업데이트
      final updatedMetadata = DeletionMetadata(
        reactivationAllowedAt: null,
        permanentBan: true,
        adminNotes: adminNotes ?? '관리자에 의한 영구 차단: $reason',
        extra: latestHistory.metadata.extra,
      );

      // Firestore 업데이트
      await _firestore.collection(_collection).doc(latestHistory.id).update({
        'metadata': updatedMetadata.toMap(),
      });

      if (kDebugMode) {
        print('✅ 영구 차단 설정 완료: $reason');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 영구 차단 설정 실패: $e');
      }
      rethrow;
    }
  }

  /// 관리자용: 재가입 허용 시점 설정
  static Future<void> setReactivationDate({
    required String? kakaoId,
    required String? email,
    required DateTime allowedAt,
    String? adminNotes,
  }) async {
    try {
      final latestHistory = await _getLatestDeletionHistory(kakaoId, email);
      
      if (latestHistory == null) {
        throw Exception('해당 사용자의 탈퇴 이력을 찾을 수 없습니다.');
      }

      // 메타데이터 업데이트
      final updatedMetadata = DeletionMetadata(
        reactivationAllowedAt: allowedAt,
        permanentBan: false,
        adminNotes: adminNotes ?? '관리자가 재가입 허용 시점을 설정함',
        extra: latestHistory.metadata.extra,
      );

      // Firestore 업데이트
      await _firestore.collection(_collection).doc(latestHistory.id).update({
        'metadata': updatedMetadata.toMap(),
      });

      if (kDebugMode) {
        print('✅ 재가입 허용 시점 설정 완료: $allowedAt');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 재가입 허용 시점 설정 실패: $e');
      }
      rethrow;
    }
  }

  /// 관리자용: 오래된 탈퇴 이력 정리 (1년 이상)
  static Future<int> cleanupOldDeletionHistory() async {
    try {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final snapshot = await _firestore
          .collection(_collection)
          .where('deletedAt', isLessThan: Timestamp.fromDate(oneYearAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        // 영구 차단이 아닌 경우만 삭제
        final history = DeletionHistory.fromFirestore(doc);
        if (!history.metadata.permanentBan) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      if (kDebugMode) {
        print('🧹 오래된 탈퇴 이력 정리 완료: ${snapshot.docs.length}개');
      }

      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 탈퇴 이력 정리 실패: $e');
      }
      return 0;
    }
  }

  // ==================== Private Methods ====================

  /// 탈퇴 횟수 조회
  static Future<int> _getDeletionCount(String? kakaoId, String? email) async {
    if (kakaoId == null && email == null) return 0;

    try {
      Query query = _firestore.collection(_collection);
      
      if (kakaoId != null) {
        query = query.where('hashedKakaoId', isEqualTo: _hashString(kakaoId));
      } else if (email != null) {
        query = query.where('hashedEmail', isEqualTo: _hashString(email));
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 탈퇴 횟수 조회 실패: $e');
      }
      return 0;
    }
  }

  /// 가장 최근 탈퇴 이력 조회
  static Future<DeletionHistory?> _getLatestDeletionHistory(String? kakaoId, String? email) async {
    if (kakaoId == null && email == null) return null;

    try {
      Query query = _firestore.collection(_collection);
      
      if (kakaoId != null) {
        query = query.where('hashedKakaoId', isEqualTo: _hashString(kakaoId));
      } else if (email != null) {
        query = query.where('hashedEmail', isEqualTo: _hashString(email));
      }

      final snapshot = await query
          .orderBy('deletedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DeletionHistory.fromFirestore(snapshot.docs.first);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 최근 탈퇴 이력 조회 실패: $e');
      }
      return null;
    }
  }

  /// 사용자 행동 점수 계산 (0-100)
  static double _calculateBehaviorScore(User user) {
    double score = 50.0; // 기본 점수

    // 평점 기반 점수 (40점 만점)
    if (user.rating > 0) {
      score += (user.rating / 5.0) * 40;
    }

    // 모임 참여도 기반 점수 (20점 만점)
    final totalMeetings = user.meetingsHosted + user.meetingsJoined;
    if (totalMeetings > 0) {
      // 로그 스케일로 점수 계산 (많이 참여할수록 높은 점수)
      final participationScore = (totalMeetings / 10.0).clamp(0.0, 1.0) * 20;
      score += participationScore;
    }

    // 호스트 비율 기반 점수 (10점 만점)
    if (totalMeetings > 0) {
      final hostRatio = user.meetingsHosted / totalMeetings;
      score += hostRatio * 10;
    }

    // TODO: 신고 횟수, 위반 기록 등으로 감점 처리
    // 현재는 기본 구현만

    return score.clamp(0.0, 100.0);
  }

  /// 문자열 해시 함수 (SHA-256 + Salt)
  static String _hashString(String input) {
    final saltedInput = '$input$_salt';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}