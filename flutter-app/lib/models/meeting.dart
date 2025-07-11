import 'package:cloud_firestore/cloud_firestore.dart';

class Meeting {
  final String id;
  final String description;
  final String location;
  final DateTime dateTime;
  final int maxParticipants;
  final int currentParticipants;
  final String hostId;
  final String hostName;
  final List<String> tags;
  final List<String> participantIds;
  final double? price;
  final double? latitude;
  final double? longitude;
  final String? restaurantName;
  final String genderPreference; // 성별 선호도: '무관', '동성만', '이성만', '동성 1명이상'
  final String? city; // 도시 정보 (예: '천안시', '서울시')
  final String? fullAddress; // 전체 주소
  final String status; // 모임 상태: 'active', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;

  Meeting({
    required this.id,
    required this.description,
    required this.location,
    required this.dateTime,
    required this.maxParticipants,
    this.currentParticipants = 1,
    required this.hostId,
    required this.hostName,
    this.tags = const [],
    this.participantIds = const [],
    this.price,
    this.latitude,
    this.longitude,
    this.restaurantName,
    this.genderPreference = '무관',
    this.city,
    this.fullAddress,
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isAvailable => currentParticipants < maxParticipants;
  
  String get timeAgo {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}일 후';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 후';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 후';
    } else {
      return '곧 시작';
    }
  }

  String get formattedDateTime {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Firestore 변환 메서드들
  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      maxParticipants: data['maxParticipants'] ?? 4,
      currentParticipants: data['currentParticipants'] ?? 1,
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      price: data['price']?.toDouble(),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      restaurantName: data['restaurantName'],
      genderPreference: data['genderPreference'] ?? '무관',
      city: data['city'] as String?,
      fullAddress: data['fullAddress'] as String?,
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'location': location,
      'dateTime': Timestamp.fromDate(dateTime),
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'hostId': hostId,
      'hostName': hostName,
      'tags': tags,
      'participantIds': participantIds,
      'price': price,
      'latitude': latitude,
      'longitude': longitude,
      'restaurantName': restaurantName,
      'genderPreference': genderPreference,
      'city': city,
      'fullAddress': fullAddress,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Meeting copyWith({
    String? id,
    String? description,
    String? location,
    DateTime? dateTime,
    int? maxParticipants,
    int? currentParticipants,
    String? hostId,
    String? hostName,
    List<String>? tags,
    List<String>? participantIds,
    double? price,
    double? latitude,
    double? longitude,
    String? restaurantName,
    String? genderPreference,
    String? city,
    String? fullAddress,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meeting(
      id: id ?? this.id,
      description: description ?? this.description,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      tags: tags ?? this.tags,
      participantIds: participantIds ?? this.participantIds,
      price: price ?? this.price,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      restaurantName: restaurantName ?? this.restaurantName,
      genderPreference: genderPreference ?? this.genderPreference,
      city: city ?? this.city,
      fullAddress: fullAddress ?? this.fullAddress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}