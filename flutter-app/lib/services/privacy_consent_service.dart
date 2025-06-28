import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PrivacyConsentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'privacy_consents';

  // 동의 상태 저장
  static Future<bool> saveConsent({
    required String userId,
    required Map<String, bool> consentData,
  }) async {
    try {
      final consentRecord = {
        'userId': userId,
        'consents': consentData,
        'consentedAt': FieldValue.serverTimestamp(),
        'version': '1.0',
        'ipAddress': '', // 필요시 추가
        'userAgent': '', // 필요시 추가
      };

      // 새로운 동의 기록 저장
      await _firestore.collection(_collection).add(consentRecord);

      // 사용자 문서에도 최신 동의 상태 저장
      await _firestore.collection('users').doc(userId).update({
        'privacyConsents': consentData,
        'lastConsentUpdate': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ 개인정보 동의 상태 저장 완료: $userId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 개인정보 동의 상태 저장 실패: $e');
      }
      return false;
    }
  }

  // 사용자의 최신 동의 상태 조회
  static Future<Map<String, bool>?> getUserConsent(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('privacyConsents')) {
          return Map<String, bool>.from(data['privacyConsents']);
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 개인정보 동의 상태 조회 실패: $e');
      }
      return null;
    }
  }

  // 동의 기록 히스토리 조회 (법적 증빙용)
  static Future<List<Map<String, dynamic>>> getConsentHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('consentedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'consents': data['consents'],
          'consentedAt': data['consentedAt'],
          'version': data['version'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 동의 기록 히스토리 조회 실패: $e');
      }
      return [];
    }
  }

  // 특정 동의 항목 업데이트
  static Future<bool> updateConsent({
    required String userId,
    required String consentType,
    required bool consentValue,
  }) async {
    try {
      // 현재 동의 상태 조회
      final currentConsents = await getUserConsent(userId) ?? {};
      
      // 특정 항목 업데이트
      currentConsents[consentType] = consentValue;
      
      // 전체 동의 상태 다시 저장
      return await saveConsent(
        userId: userId,
        consentData: currentConsents,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 개인정보 동의 상태 업데이트 실패: $e');
      }
      return false;
    }
  }

  // 동의 철회 (필수 항목은 철회 불가)
  static Future<bool> revokeConsent({
    required String userId,
    required String consentType,
  }) async {
    // 필수 동의 항목은 철회 불가
    if (consentType == 'essential') {
      throw Exception('필수 동의 항목은 철회할 수 없습니다. 회원 탈퇴를 통해서만 가능합니다.');
    }

    return await updateConsent(
      userId: userId,
      consentType: consentType,
      consentValue: false,
    );
  }

  // 사용자가 필수 동의를 했는지 확인
  static Future<bool> hasEssentialConsent(String userId) async {
    try {
      final consents = await getUserConsent(userId);
      return consents?['essential'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 필수 동의 확인 실패: $e');
      }
      return false;
    }
  }

  // 특정 동의 항목 상태 확인
  static Future<bool> hasConsent(String userId, String consentType) async {
    try {
      final consents = await getUserConsent(userId);
      return consents?[consentType] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 동의 상태 확인 실패: $e');
      }
      return false;
    }
  }

  // 회원 탈퇴 시 동의 기록 삭제 (GDPR 준수)
  static Future<bool> deleteAllConsents(String userId) async {
    try {
      // 동의 기록들 조회
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      // 배치 삭제
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // 사용자 문서에서도 동의 정보 삭제
      await _firestore.collection('users').doc(userId).update({
        'privacyConsents': FieldValue.delete(),
        'lastConsentUpdate': FieldValue.delete(),
      });

      if (kDebugMode) {
        print('✅ 사용자 동의 기록 전체 삭제 완료: $userId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 동의 기록 삭제 실패: $e');
      }
      return false;
    }
  }

  // 동의 상태 검증 (회원가입 시 사용)
  static bool validateConsents(Map<String, bool> consents) {
    // 필수 동의 항목 확인
    if (consents['essential'] != true) {
      return false;
    }

    // 선택 동의 항목들은 true/false 모두 가능
    final validKeys = ['essential', 'optional_profile', 'marketing'];
    
    // 유효하지 않은 키가 있는지 확인
    for (final key in consents.keys) {
      if (!validKeys.contains(key)) {
        return false;
      }
    }

    return true;
  }

  // 동의 상태 요약 정보 (관리자용)
  static Future<Map<String, dynamic>> getConsentSummary(String userId) async {
    try {
      final consents = await getUserConsent(userId);
      final history = await getConsentHistory(userId);

      return {
        'currentConsents': consents,
        'totalConsentRecords': history.length,
        'lastUpdated': history.isNotEmpty ? history.first['consentedAt'] : null,
        'hasEssentialConsent': consents?['essential'] ?? false,
        'hasOptionalProfileConsent': consents?['optional_profile'] ?? false,
        'hasMarketingConsent': consents?['marketing'] ?? false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 동의 상태 요약 조회 실패: $e');
      }
      return {};
    }
  }
}