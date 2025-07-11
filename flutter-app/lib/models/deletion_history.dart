import 'package:cloud_firestore/cloud_firestore.dart';

/// 회원탈퇴 이력 관리 모델
/// 개인정보는 해시화하여 저장하고, 사용자 행동 패턴을 분석
class DeletionHistory {
  final String id;
  final String hashedKakaoId;          // 해시된 카카오 ID (필수)
  final String? hashedEmail;           // 해시된 이메일 (선택)
  final String deletionReason;         // 탈퇴 사유
  final int deletionCount;             // 탈퇴 횟수 (1, 2, 3...)
  final DateTime deletedAt;            // 탈퇴 시간
  final String? hashedLastNickname;    // 마지막 사용 닉네임 (해시)
  final double behaviorScore;          // 행동 점수 (0-100, 높을수록 양호)
  final int reportCount;               // 신고 당한 횟수
  final int meetingsHosted;            // 주최했던 모임 수
  final int meetingsJoined;            // 참여했던 모임 수
  final double averageRating;          // 평균 평점 (0.0-5.0)
  final List<String> violations;       // 위반 사항들
  final DeletionMetadata metadata;     // 추가 메타데이터

  DeletionHistory({
    required this.id,
    required this.hashedKakaoId,
    this.hashedEmail,
    required this.deletionReason,
    required this.deletionCount,
    required this.deletedAt,
    this.hashedLastNickname,
    this.behaviorScore = 50.0, // 기본값: 중간 점수
    this.reportCount = 0,
    this.meetingsHosted = 0,
    this.meetingsJoined = 0,
    this.averageRating = 0.0,
    this.violations = const [],
    required this.metadata,
  });

  factory DeletionHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeletionHistory(
      id: doc.id,
      hashedKakaoId: data['hashedKakaoId'] ?? '',
      hashedEmail: data['hashedEmail'],
      deletionReason: data['deletionReason'] ?? '사용자 요청',
      deletionCount: data['deletionCount'] ?? 1,
      deletedAt: (data['deletedAt'] as Timestamp).toDate(),
      hashedLastNickname: data['hashedLastNickname'],
      behaviorScore: (data['behaviorScore'] ?? 50.0).toDouble(),
      reportCount: data['reportCount'] ?? 0,
      meetingsHosted: data['meetingsHosted'] ?? 0,
      meetingsJoined: data['meetingsJoined'] ?? 0,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      violations: List<String>.from(data['violations'] ?? []),
      metadata: DeletionMetadata.fromMap(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hashedKakaoId': hashedKakaoId,
      'hashedEmail': hashedEmail,
      'deletionReason': deletionReason,
      'deletionCount': deletionCount,
      'deletedAt': Timestamp.fromDate(deletedAt),
      'hashedLastNickname': hashedLastNickname,
      'behaviorScore': behaviorScore,
      'reportCount': reportCount,
      'meetingsHosted': meetingsHosted,
      'meetingsJoined': meetingsJoined,
      'averageRating': averageRating,
      'violations': violations,
      'metadata': metadata.toMap(),
    };
  }

  /// 사용자 등급 계산 (A, B, C, D)
  UserGrade get userGrade {
    if (violations.contains('permanent_ban') || reportCount >= 5) {
      return UserGrade.D; // 영구 차단
    }
    
    if (behaviorScore >= 80 && reportCount == 0 && deletionCount <= 1) {
      return UserGrade.A; // 모범 사용자
    }
    
    if (behaviorScore >= 60 && reportCount <= 1 && deletionCount <= 2) {
      return UserGrade.B; // 일반 사용자
    }
    
    if (behaviorScore >= 30 && reportCount <= 3 && deletionCount <= 3) {
      return UserGrade.C; // 주의 사용자
    }
    
    return UserGrade.D; // 위험 사용자
  }

  /// 재가입 허용 여부 및 대기 시간 계산
  ReactivationStatus get reactivationStatus {
    // 영구 차단 확인
    if (metadata.permanentBan || userGrade == UserGrade.D) {
      return ReactivationStatus(
        allowed: false,
        waitDays: -1, // 영구
        reason: '영구 차단된 사용자입니다.',
      );
    }

    // 관리자가 설정한 재가입 허용 시점 확인
    if (metadata.reactivationAllowedAt != null) {
      final now = DateTime.now();
      if (now.isBefore(metadata.reactivationAllowedAt!)) {
        final waitDays = metadata.reactivationAllowedAt!.difference(now).inDays;
        return ReactivationStatus(
          allowed: false,
          waitDays: waitDays,
          reason: '관리자가 설정한 대기 기간입니다.',
        );
      }
    }

    // 등급별 기본 대기 기간
    final now = DateTime.now();
    final daysSinceDeletion = now.difference(deletedAt).inDays;
    
    switch (userGrade) {
      case UserGrade.A:
        return ReactivationStatus(
          allowed: true,
          waitDays: 0,
          reason: '모범 사용자로 즉시 재가입 가능합니다.',
        );
      
      case UserGrade.B:
        const waitPeriod = 7;
        if (daysSinceDeletion >= waitPeriod) {
          return ReactivationStatus(
            allowed: true,
            waitDays: 0,
            reason: '재가입이 가능합니다.',
          );
        }
        return ReactivationStatus(
          allowed: false,
          waitDays: waitPeriod - daysSinceDeletion,
          reason: '7일 대기 기간이 필요합니다.',
        );
      
      case UserGrade.C:
        const waitPeriod = 30;
        if (daysSinceDeletion >= waitPeriod) {
          return ReactivationStatus(
            allowed: true,
            waitDays: 0,
            reason: '재가입이 가능합니다.',
          );
        }
        return ReactivationStatus(
          allowed: false,
          waitDays: waitPeriod - daysSinceDeletion,
          reason: '30일 대기 기간이 필요합니다.',
        );
      
      case UserGrade.D:
        return ReactivationStatus(
          allowed: false,
          waitDays: -1,
          reason: '재가입이 제한된 사용자입니다.',
        );
    }
  }

  /// 행동 점수 업데이트
  DeletionHistory updateBehaviorScore(double newScore) {
    return DeletionHistory(
      id: id,
      hashedKakaoId: hashedKakaoId,
      hashedEmail: hashedEmail,
      deletionReason: deletionReason,
      deletionCount: deletionCount,
      deletedAt: deletedAt,
      hashedLastNickname: hashedLastNickname,
      behaviorScore: newScore.clamp(0.0, 100.0),
      reportCount: reportCount,
      meetingsHosted: meetingsHosted,
      meetingsJoined: meetingsJoined,
      averageRating: averageRating,
      violations: violations,
      metadata: metadata,
    );
  }
}

/// 탈퇴 이력 메타데이터
class DeletionMetadata {
  final DateTime? reactivationAllowedAt;  // 재가입 허용 시점
  final bool permanentBan;                // 영구 차단 여부
  final String? adminNotes;               // 관리자 메모
  final Map<String, dynamic> extra;       // 추가 정보

  const DeletionMetadata({
    this.reactivationAllowedAt,
    this.permanentBan = false,
    this.adminNotes,
    this.extra = const {},
  });

  factory DeletionMetadata.fromMap(Map<String, dynamic> map) {
    return DeletionMetadata(
      reactivationAllowedAt: map['reactivationAllowedAt'] != null 
          ? (map['reactivationAllowedAt'] as Timestamp).toDate()
          : null,
      permanentBan: map['permanentBan'] ?? false,
      adminNotes: map['adminNotes'],
      extra: Map<String, dynamic>.from(map['extra'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reactivationAllowedAt': reactivationAllowedAt != null 
          ? Timestamp.fromDate(reactivationAllowedAt!)
          : null,
      'permanentBan': permanentBan,
      'adminNotes': adminNotes,
      'extra': extra,
    };
  }
}

/// 사용자 등급
enum UserGrade {
  A, // 모범 사용자 (즉시 재가입)
  B, // 일반 사용자 (7일 대기)
  C, // 주의 사용자 (30일 대기)
  D, // 위험 사용자 (영구 차단)
}

/// 재가입 상태
class ReactivationStatus {
  final bool allowed;        // 재가입 허용 여부
  final int waitDays;        // 대기 일수 (-1이면 영구)
  final String reason;       // 사유

  const ReactivationStatus({
    required this.allowed,
    required this.waitDays,
    required this.reason,
  });

  /// 사용자에게 표시할 메시지
  String get displayMessage {
    if (allowed) {
      return reason;
    }
    
    if (waitDays == -1) {
      return '재가입이 영구적으로 제한되었습니다.\n$reason';
    }
    
    return '재가입까지 ${waitDays}일 남았습니다.\n$reason';
  }
}