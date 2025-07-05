import 'package:cloud_firestore/cloud_firestore.dart';

class UserBlacklist {
  final String id;
  final String? hashedKakaoId;
  final String? hashedPhoneNumber;
  final String blockReason;
  final String blockType; // repeated_deletion, reported, admin_action
  final DateTime blockedAt;
  final DateTime? expiresAt; // null이면 영구 차단
  final Map<String, dynamic>? metadata; // 추가 정보

  UserBlacklist({
    required this.id,
    this.hashedKakaoId,
    this.hashedPhoneNumber,
    required this.blockReason,
    required this.blockType,
    required this.blockedAt,
    this.expiresAt,
    this.metadata,
  });

  factory UserBlacklist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserBlacklist(
      id: doc.id,
      hashedKakaoId: data['hashedKakaoId'],
      hashedPhoneNumber: data['hashedPhoneNumber'],
      blockReason: data['blockReason'] ?? '',
      blockType: data['blockType'] ?? 'repeated_deletion',
      blockedAt: (data['blockedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hashedKakaoId': hashedKakaoId,
      'hashedPhoneNumber': hashedPhoneNumber,
      'blockReason': blockReason,
      'blockType': blockType,
      'blockedAt': Timestamp.fromDate(blockedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'metadata': metadata,
    };
  }

  /// 차단이 아직 유효한지 확인
  bool get isActive {
    if (expiresAt == null) return true; // 영구 차단
    return DateTime.now().isBefore(expiresAt!);
  }

  /// 차단 유형별 기본 차단 기간 계산
  static DateTime? calculateExpirationDate(String blockType) {
    final now = DateTime.now();
    switch (blockType) {
      case 'first_deletion':
        return now.add(const Duration(days: 7)); // 7일 제한
      case 'repeated_deletion':
        return now.add(const Duration(days: 30)); // 30일 제한
      case 'reported':
      case 'admin_action':
        return null; // 영구 차단
      default:
        return now.add(const Duration(days: 7));
    }
  }
}