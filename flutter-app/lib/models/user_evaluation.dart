import 'package:cloud_firestore/cloud_firestore.dart';

class UserEvaluation {
  final String id;
  final String meetingId;
  final String evaluatorId; // 평가자 ID
  final String evaluatedUserId; // 평가받는 사용자 ID
  final int punctualityRating; // 시간준수 (1-5)
  final int friendlinessRating; // 대화매너 (1-5)
  final int communicationRating; // 재만남의향 (1-5)
  final String? comment; // 추가 코멘트 (선택사항)
  final DateTime createdAt;

  UserEvaluation({
    required this.id,
    required this.meetingId,
    required this.evaluatorId,
    required this.evaluatedUserId,
    required this.punctualityRating,
    required this.friendlinessRating,
    required this.communicationRating,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserEvaluation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserEvaluation(
      id: doc.id,
      meetingId: data['meetingId'] ?? '',
      evaluatorId: data['evaluatorId'] ?? '',
      evaluatedUserId: data['evaluatedUserId'] ?? '',
      punctualityRating: data['punctualityRating'] ?? 5,
      friendlinessRating: data['friendlinessRating'] ?? 5,
      communicationRating: data['communicationRating'] ?? 5,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'evaluatorId': evaluatorId,
      'evaluatedUserId': evaluatedUserId,
      'punctualityRating': punctualityRating,
      'friendlinessRating': friendlinessRating,
      'communicationRating': communicationRating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  double get averageRating {
    return (punctualityRating + friendlinessRating + communicationRating) / 3.0;
  }

  UserEvaluation copyWith({
    String? id,
    String? meetingId,
    String? evaluatorId,
    String? evaluatedUserId,
    int? punctualityRating,
    int? friendlinessRating,
    int? communicationRating,
    String? comment,
    DateTime? createdAt,
  }) {
    return UserEvaluation(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      evaluatorId: evaluatorId ?? this.evaluatorId,
      evaluatedUserId: evaluatedUserId ?? this.evaluatedUserId,
      punctualityRating: punctualityRating ?? this.punctualityRating,
      friendlinessRating: friendlinessRating ?? this.friendlinessRating,
      communicationRating: communicationRating ?? this.communicationRating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}