import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantEvaluation {
  final String id;
  final String restaurantId; // 카카오 place_id
  final String restaurantName; // 식당명
  final String evaluatorId; // 평가자 ID
  final String meetingId; // 모임 ID (참조용)
  final int rating; // 식당 평점 (1-5)
  final String? comment; // 식당에 대한 코멘트 (선택사항)
  final DateTime createdAt;

  RestaurantEvaluation({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.evaluatorId,
    required this.meetingId,
    required this.rating,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RestaurantEvaluation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RestaurantEvaluation(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      evaluatorId: data['evaluatorId'] ?? '',
      meetingId: data['meetingId'] ?? '',
      rating: data['rating'] ?? 5,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'evaluatorId': evaluatorId,
      'meetingId': meetingId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  RestaurantEvaluation copyWith({
    String? id,
    String? restaurantId,
    String? restaurantName,
    String? evaluatorId,
    String? meetingId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return RestaurantEvaluation(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      evaluatorId: evaluatorId ?? this.evaluatorId,
      meetingId: meetingId ?? this.meetingId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}