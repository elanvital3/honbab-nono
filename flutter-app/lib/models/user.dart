import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? bio;
  final String? kakaoId;
  final String? fcmToken;  // FCM 푸시 알림 토큰
  final String? currentChatRoom;  // 현재 활성 채팅방 ID (알림 필터링용)
  final double? lastLatitude;  // 마지막 위치 (위도)
  final double? lastLongitude; // 마지막 위치 (경도)
  final DateTime? lastLocationUpdated; // 마지막 위치 업데이트 시간
  final double rating;
  final int meetingsHosted;
  final int meetingsJoined;
  final List<String> favoriteRestaurants;
  final List<String> badges; // 사용자 특성 뱃지 ID 목록
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.bio,
    this.kakaoId,
    this.fcmToken,
    this.currentChatRoom,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationUpdated,
    this.rating = 0.0,
    this.meetingsHosted = 0,
    this.meetingsJoined = 0,
    this.favoriteRestaurants = const [],
    this.badges = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      bio: data['bio'],
      kakaoId: data['kakaoId'],
      fcmToken: data['fcmToken'],
      currentChatRoom: data['currentChatRoom'],
      lastLatitude: data['lastLatitude']?.toDouble(),
      lastLongitude: data['lastLongitude']?.toDouble(),
      lastLocationUpdated: (data['lastLocationUpdated'] as Timestamp?)?.toDate(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      meetingsHosted: data['meetingsHosted'] ?? 0,
      meetingsJoined: data['meetingsJoined'] ?? 0,
      favoriteRestaurants: List<String>.from(data['favoriteRestaurants'] ?? []),
      badges: List<String>.from(data['badges'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'kakaoId': kakaoId,
      'fcmToken': fcmToken,
      'currentChatRoom': currentChatRoom,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastLocationUpdated': lastLocationUpdated != null ? Timestamp.fromDate(lastLocationUpdated!) : null,
      'rating': rating,
      'meetingsHosted': meetingsHosted,
      'meetingsJoined': meetingsJoined,
      'favoriteRestaurants': favoriteRestaurants,
      'badges': badges,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    String? bio,
    String? kakaoId,
    String? fcmToken,
    String? currentChatRoom,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastLocationUpdated,
    double? rating,
    int? meetingsHosted,
    int? meetingsJoined,
    List<String>? favoriteRestaurants,
    List<String>? badges,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      kakaoId: kakaoId ?? this.kakaoId,
      fcmToken: fcmToken ?? this.fcmToken,
      currentChatRoom: currentChatRoom ?? this.currentChatRoom,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastLocationUpdated: lastLocationUpdated ?? this.lastLocationUpdated,
      rating: rating ?? this.rating,
      meetingsHosted: meetingsHosted ?? this.meetingsHosted,
      meetingsJoined: meetingsJoined ?? this.meetingsJoined,
      favoriteRestaurants: favoriteRestaurants ?? this.favoriteRestaurants,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}