import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  final List<String> pendingApplicantIds; // 승인 대기중인 신청자 ID 목록
  final double? price;
  final double? latitude;
  final double? longitude;
  final String? restaurantName;
  final String? restaurantId; // 즐겨찾기 시스템을 위한 식당 ID
  final String genderPreference; // 성별 선호도: '무관', '동성만', '이성만', '동성 1명이상'
  final String? city; // 도시 정보 (예: '천안시', '서울시')
  final String? fullAddress; // 전체 주소
  final String status; // 모임 상태: 'active', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? representativeImageUrl; // 대표 이미지 URL (식당 이미지)
  final bool chatActive; // 채팅방 활성 상태 (모임 완료 후에도 채팅 가능 여부)

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
    this.pendingApplicantIds = const [],
    this.price,
    this.latitude,
    this.longitude,
    this.restaurantName,
    this.restaurantId,
    this.genderPreference = '무관',
    this.city,
    this.fullAddress,
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.representativeImageUrl,
    this.chatActive = true,
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
    try {
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
        throw Exception('Document data is null for meeting ${doc.id}');
      }
      
      // dateTime 필드 안전하게 처리
      DateTime parseDateTime() {
        final dateTimeField = data['dateTime'];
        if (dateTimeField == null) {
          throw Exception('dateTime field is missing in meeting ${doc.id}');
        }
        if (dateTimeField is Timestamp) {
          return dateTimeField.toDate();
        }
        throw Exception('dateTime field is not a Timestamp in meeting ${doc.id}: ${dateTimeField.runtimeType}');
      }
      
      // 배열 필드들 안전하게 처리
      List<String> parseStringList(String fieldName) {
        final field = data[fieldName];
        if (field == null) return [];
        if (field is List) {
          return field.map((item) => item.toString()).toList();
        }
        return [];
      }
      
      return Meeting(
        id: doc.id,
        description: data['description']?.toString() ?? '',
        location: data['location']?.toString() ?? '',
        dateTime: parseDateTime(),
        maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 4,
        currentParticipants: (data['currentParticipants'] as num?)?.toInt() ?? 1,
        hostId: data['hostId']?.toString() ?? '',
        hostName: data['hostName']?.toString() ?? '',
        tags: parseStringList('tags'),
        participantIds: parseStringList('participantIds'),
        pendingApplicantIds: parseStringList('pendingApplicantIds'),
        price: (data['price'] as num?)?.toDouble(),
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        restaurantName: data['restaurantName']?.toString(),
        restaurantId: data['restaurantId']?.toString(),
        genderPreference: data['genderPreference']?.toString() ?? '무관',
        city: data['city']?.toString(),
        fullAddress: data['fullAddress']?.toString(),
        status: data['status']?.toString() ?? 'active',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        representativeImageUrl: data['representativeImageUrl']?.toString(),
        chatActive: data['chatActive'] as bool? ?? true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Meeting.fromFirestore 파싱 에러 - 문서 ID: ${doc.id}');
        print('❌ 에러: $e');
        print('❌ 문서 데이터: ${doc.data()}');
      }
      rethrow;
    }
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
      'pendingApplicantIds': pendingApplicantIds,
      'price': price,
      'latitude': latitude,
      'longitude': longitude,
      'restaurantName': restaurantName,
      'restaurantId': restaurantId,
      'genderPreference': genderPreference,
      'city': city,
      'fullAddress': fullAddress,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'representativeImageUrl': representativeImageUrl,
      'chatActive': chatActive,
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
    List<String>? pendingApplicantIds,
    double? price,
    double? latitude,
    double? longitude,
    String? restaurantName,
    String? restaurantId,
    String? genderPreference,
    String? city,
    String? fullAddress,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? representativeImageUrl,
    bool? chatActive,
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
      pendingApplicantIds: pendingApplicantIds ?? this.pendingApplicantIds,
      price: price ?? this.price,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantId: restaurantId ?? this.restaurantId,
      genderPreference: genderPreference ?? this.genderPreference,
      city: city ?? this.city,
      fullAddress: fullAddress ?? this.fullAddress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      representativeImageUrl: representativeImageUrl ?? this.representativeImageUrl,
      chatActive: chatActive ?? this.chatActive,
    );
  }
}