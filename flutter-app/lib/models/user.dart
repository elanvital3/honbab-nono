import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? bio;
  final String? kakaoId;
  final double rating;
  final int meetingsHosted;
  final int meetingsJoined;
  final List<String> favoriteRestaurants;
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
    this.rating = 0.0,
    this.meetingsHosted = 0,
    this.meetingsJoined = 0,
    this.favoriteRestaurants = const [],
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
      rating: (data['rating'] ?? 0.0).toDouble(),
      meetingsHosted: data['meetingsHosted'] ?? 0,
      meetingsJoined: data['meetingsJoined'] ?? 0,
      favoriteRestaurants: List<String>.from(data['favoriteRestaurants'] ?? []),
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
      'rating': rating,
      'meetingsHosted': meetingsHosted,
      'meetingsJoined': meetingsJoined,
      'favoriteRestaurants': favoriteRestaurants,
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
    double? rating,
    int? meetingsHosted,
    int? meetingsJoined,
    List<String>? favoriteRestaurants,
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
      rating: rating ?? this.rating,
      meetingsHosted: meetingsHosted ?? this.meetingsHosted,
      meetingsJoined: meetingsJoined ?? this.meetingsJoined,
      favoriteRestaurants: favoriteRestaurants ?? this.favoriteRestaurants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}