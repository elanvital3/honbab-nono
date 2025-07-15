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
  
  // 모임 정보 (코멘트와 함께 저장)
  final String? meetingLocation; // 모임 장소 주소
  final String? meetingRestaurant; // 식당명
  final DateTime? meetingDateTime; // 모임 일시
  
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
    this.meetingLocation,
    this.meetingRestaurant,
    this.meetingDateTime,
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
      meetingLocation: data['meetingLocation'],
      meetingRestaurant: data['meetingRestaurant'],
      meetingDateTime: (data['meetingDateTime'] as Timestamp?)?.toDate(),
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
      'meetingLocation': meetingLocation,
      'meetingRestaurant': meetingRestaurant,
      'meetingDateTime': meetingDateTime != null ? Timestamp.fromDate(meetingDateTime!) : null,
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
    String? meetingLocation,
    String? meetingRestaurant,
    DateTime? meetingDateTime,
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
      meetingLocation: meetingLocation ?? this.meetingLocation,
      meetingRestaurant: meetingRestaurant ?? this.meetingRestaurant,
      meetingDateTime: meetingDateTime ?? this.meetingDateTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}