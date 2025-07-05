import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../models/user_blacklist.dart';

class BlacklistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_blacklist';

  /// 사용자를 블랙리스트에 추가
  static Future<void> addToBlacklist({
    required String? kakaoId,
    required String? phoneNumber,
    required String blockReason,
    required String blockType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (kakaoId == null && phoneNumber == null) {
        throw Exception('카카오 ID 또는 전화번호 중 하나는 필수입니다');
      }

      final blacklist = UserBlacklist(
        id: '', // Firestore에서 자동 생성
        hashedKakaoId: kakaoId != null ? _hashString(kakaoId) : null,
        hashedPhoneNumber: phoneNumber != null ? _hashString(phoneNumber) : null,
        blockReason: blockReason,
        blockType: blockType,
        blockedAt: DateTime.now(),
        expiresAt: UserBlacklist.calculateExpirationDate(blockType),
        metadata: metadata,
      );

      await _firestore.collection(_collection).add(blacklist.toFirestore());

      if (kDebugMode) {
        print('🚫 블랙리스트 추가 완료:');
        print('   - 차단 유형: $blockType');
        print('   - 차단 사유: $blockReason');
        print('   - 만료 일시: ${blacklist.expiresAt ?? "영구"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 블랙리스트 추가 실패: $e');
      }
      rethrow;
    }
  }

  /// 사용자가 블랙리스트에 있는지 확인
  static Future<UserBlacklist?> checkBlacklist({
    required String? kakaoId,
    required String? phoneNumber,
  }) async {
    try {
      if (kakaoId == null && phoneNumber == null) {
        return null;
      }

      Query query = _firestore.collection(_collection);

      // 카카오 ID 또는 전화번호로 검색
      if (kakaoId != null) {
        final hashedKakaoId = _hashString(kakaoId);
        query = query.where('hashedKakaoId', isEqualTo: hashedKakaoId);
      } else if (phoneNumber != null) {
        final hashedPhoneNumber = _hashString(phoneNumber);
        query = query.where('hashedPhoneNumber', isEqualTo: hashedPhoneNumber);
      }

      final snapshot = await query.get();

      // 활성 차단 기록 찾기
      for (final doc in snapshot.docs) {
        final blacklist = UserBlacklist.fromFirestore(doc);
        if (blacklist.isActive) {
          if (kDebugMode) {
            print('🚫 블랙리스트 사용자 발견:');
            print('   - 차단 유형: ${blacklist.blockType}');
            print('   - 만료 일시: ${blacklist.expiresAt ?? "영구"}');
          }
          return blacklist;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 블랙리스트 확인 실패: $e');
      }
      return null; // 오류 시 차단하지 않음
    }
  }

  /// 탈퇴 횟수 기반 차단 유형 결정
  static Future<String> determineBlockType({
    required String? kakaoId,
    required String? phoneNumber,
  }) async {
    try {
      if (kakaoId == null && phoneNumber == null) {
        return 'first_deletion';
      }

      // 이전 탈퇴 기록 수 조회
      int deletionCount = 0;

      if (kakaoId != null) {
        final hashedKakaoId = _hashString(kakaoId);
        final kakaoRecords = await _firestore
            .collection(_collection)
            .where('hashedKakaoId', isEqualTo: hashedKakaoId)
            .where('blockType', whereIn: ['first_deletion', 'repeated_deletion'])
            .get();
        deletionCount += kakaoRecords.docs.length;
      }

      if (phoneNumber != null) {
        final hashedPhoneNumber = _hashString(phoneNumber);
        final phoneRecords = await _firestore
            .collection(_collection)
            .where('hashedPhoneNumber', isEqualTo: hashedPhoneNumber)
            .where('blockType', whereIn: ['first_deletion', 'repeated_deletion'])
            .get();
        deletionCount += phoneRecords.docs.length;
      }

      // 탈퇴 횟수에 따른 차단 유형 결정
      if (deletionCount == 0) {
        return 'first_deletion';
      } else {
        return 'repeated_deletion';
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 차단 유형 결정 실패: $e');
      }
      return 'first_deletion'; // 기본값
    }
  }

  /// 만료된 블랙리스트 항목 정리 (관리용)
  static Future<int> cleanupExpiredBlacklist() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final snapshot = await _firestore
          .collection(_collection)
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('🧹 만료된 블랙리스트 정리 완료: ${snapshot.docs.length}개');
      }

      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 블랙리스트 정리 실패: $e');
      }
      return 0;
    }
  }

  /// 문자열 해시 함수 (SHA-256 + Salt)
  static String _hashString(String input) {
    const salt = 'honbab_nono_salt_2024'; // 앱별 고유 솔트
    final saltedInput = '$input$salt';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 블랙리스트 사유별 메시지 생성
  static String getBlockMessage(UserBlacklist blacklist) {
    final expiryText = blacklist.expiresAt != null 
        ? '${blacklist.expiresAt!.year}년 ${blacklist.expiresAt!.month}월 ${blacklist.expiresAt!.day}일까지'
        : '영구적으로';

    switch (blacklist.blockType) {
      case 'first_deletion':
        return '회원탈퇴 후 재가입이 제한됩니다.\n$expiryText 가입이 제한됩니다.';
      case 'repeated_deletion':
        return '반복적인 탈퇴로 인해 가입이 제한됩니다.\n$expiryText 가입이 제한됩니다.';
      case 'reported':
        return '신고 접수로 인해 가입이 제한됩니다.\n자세한 사항은 고객센터로 문의해주세요.';
      case 'admin_action':
        return '관리자에 의해 가입이 제한되었습니다.\n자세한 사항은 고객센터로 문의해주세요.';
      default:
        return '가입이 제한되었습니다.\n자세한 사항은 고객센터로 문의해주세요.';
    }
  }
}