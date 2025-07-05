// 유튜브 통계 정보
class YoutubeStats {
  final int mentionCount;
  final List<String> channels;
  final String? firstMentionDate;
  final String? lastMentionDate;
  final int recentMentions;
  final RepresentativeVideo? representativeVideo;

  YoutubeStats({
    required this.mentionCount,
    required this.channels,
    this.firstMentionDate,
    this.lastMentionDate,
    required this.recentMentions,
    this.representativeVideo,
  });

  factory YoutubeStats.fromMap(Map<String, dynamic> data) {
    return YoutubeStats(
      mentionCount: data['mentionCount'] as int? ?? 0,
      channels: List<String>.from(data['channels'] as List? ?? []),
      firstMentionDate: data['firstMentionDate'] as String?,
      lastMentionDate: data['lastMentionDate'] as String?,
      recentMentions: data['recentMentions'] as int? ?? 0,
      representativeVideo: data['representativeVideo'] != null
          ? RepresentativeVideo.fromMap(data['representativeVideo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mentionCount': mentionCount,
      'channels': channels,
      'firstMentionDate': firstMentionDate,
      'lastMentionDate': lastMentionDate,
      'recentMentions': recentMentions,
      'representativeVideo': representativeVideo?.toMap(),
    };
  }
}

// 대표 유튜브 영상 정보
class RepresentativeVideo {
  final String title;
  final String channelName;
  final String videoId;
  final int viewCount;
  final String publishedAt;
  final String? thumbnailUrl;

  RepresentativeVideo({
    required this.title,
    required this.channelName,
    required this.videoId,
    required this.viewCount,
    required this.publishedAt,
    this.thumbnailUrl,
  });

  factory RepresentativeVideo.fromMap(Map<String, dynamic> data) {
    return RepresentativeVideo(
      title: data['title'] as String? ?? '',
      channelName: data['channelName'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      viewCount: data['viewCount'] as int? ?? 0,
      publishedAt: data['publishedAt'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'channelName': channelName,
      'videoId': videoId,
      'viewCount': viewCount,
      'publishedAt': publishedAt,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

// Google Places 데이터 정보
class GooglePlacesData {
  final String? placeId;
  final double? rating;
  final int userRatingsTotal;
  final List<GoogleReview> reviews;
  final List<String> photos;
  final int? priceLevel;
  final bool? isOpen;
  final String? phoneNumber;
  final Map<String, dynamic>? regularOpeningHours;
  final DateTime? updatedAt;

  GooglePlacesData({
    this.placeId,
    this.rating,
    required this.userRatingsTotal,
    required this.reviews,
    required this.photos,
    this.priceLevel,
    this.isOpen,
    this.phoneNumber,
    this.regularOpeningHours,
    this.updatedAt,
  });

  factory GooglePlacesData.fromMap(Map<String, dynamic> data) {
    return GooglePlacesData(
      placeId: data['placeId'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      userRatingsTotal: data['userRatingsTotal'] as int? ?? 0,
      reviews: (data['reviews'] as List? ?? [])
          .map((review) => GoogleReview.fromMap(review as Map<String, dynamic>))
          .toList(),
      photos: List<String>.from(data['photos'] as List? ?? []),
      priceLevel: data['priceLevel'] as int?,
      isOpen: data['isOpen'] as bool?,
      phoneNumber: data['phoneNumber'] as String?,
      regularOpeningHours: data['regularOpeningHours'] as Map<String, dynamic>?,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as dynamic).toDate() as DateTime?
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'reviews': reviews.map((review) => review.toMap()).toList(),
      'photos': photos,
      'priceLevel': priceLevel,
      'isOpen': isOpen,
      'phoneNumber': phoneNumber,
      'regularOpeningHours': regularOpeningHours,
      'updatedAt': updatedAt,
    };
  }
}

// Google 리뷰 정보
class GoogleReview {
  final String authorName;
  final int rating;
  final String text;
  final int time;
  final String? profilePhotoUrl;

  GoogleReview({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.time,
    this.profilePhotoUrl,
  });

  factory GoogleReview.fromMap(Map<String, dynamic> data) {
    return GoogleReview(
      authorName: data['author_name'] as String? ?? '',
      rating: data['rating'] as int? ?? 5,
      text: data['text'] as String? ?? '',
      time: data['time'] as int? ?? 0,
      profilePhotoUrl: data['profile_photo_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'author_name': authorName,
      'rating': rating,
      'text': text,
      'time': time,
      'profile_photo_url': profilePhotoUrl,
    };
  }

  // 리뷰 날짜 포맷팅
  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return '오늘';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}주 전';
    } else if (difference.inDays < 365) {
      return '${difference.inDays ~/ 30}개월 전';
    } else {
      return '${difference.inDays ~/ 365}년 전';
    }
  }
}

// 트렌드 점수 정보
class TrendScore {
  final int hotness;
  final int consistency;
  final bool isRising;
  final int recentMentions;

  TrendScore({
    required this.hotness,
    required this.consistency,
    required this.isRising,
    required this.recentMentions,
  });

  factory TrendScore.fromMap(Map<String, dynamic> data) {
    return TrendScore(
      hotness: data['hotness'] as int? ?? 0,
      consistency: data['consistency'] as int? ?? 0,
      isRising: data['isRising'] as bool? ?? false,
      recentMentions: data['recentMentions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hotness': hotness,
      'consistency': consistency,
      'isRising': isRising,
      'recentMentions': recentMentions,
    };
  }
}

class Restaurant {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final String? phone;
  final String? url;
  final double? rating;
  String? distance; // mutable로 변경 (거리 계산 후 업데이트용)
  final String? city;
  final String? province;
  final bool? isActive;
  final DateTime? updatedAt;
  final String? imageUrl; // 대표 이미지 URL 추가
  
  // 유튜브 데이터 필드들
  final YoutubeStats? youtubeStats;
  final List<String>? featureTags;
  final TrendScore? trendScore;
  
  // Google Places 데이터 필드들
  final GooglePlacesData? googlePlaces;
  
  // 표시용 거리 문자열 (동적 계산 결과 저장)
  String displayDistance = '';

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.phone,
    this.url,
    this.rating,
    this.distance,
    this.city,
    this.province,
    this.isActive,
    this.updatedAt,
    this.imageUrl,
    this.youtubeStats,
    this.featureTags,
    this.trendScore,
    this.googlePlaces,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['place_name'] as String,
      address: json['address_name'] as String,
      latitude: double.parse(json['y']),
      longitude: double.parse(json['x']),
      category: json['category_name'] as String,
      phone: json['phone'] as String?,
      url: json['place_url'] as String?,
      distance: json['distance'] as String?,
      imageUrl: json['image_url'] as String?, // 이미지 URL 파싱 추가
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place_name': name,
      'address_name': address,
      'y': latitude.toString(),
      'x': longitude.toString(),
      'category_name': category,
      'phone': phone,
      'place_url': url,
      'distance': distance,
      'image_url': imageUrl,
    };
  }

  String get shortCategory {
    final parts = category.split(' > ');
    return parts.length > 1 ? parts.last : category;
  }

  String get formattedDistance {
    try {
      // 동적 계산된 displayDistance가 있으면 우선 사용
      if (displayDistance.isNotEmpty) {
        return displayDistance;
      }
      
      // 없으면 기존 distance 값으로 포맷팅
      if (distance == null) return '';
      final distanceInMeters = int.tryParse(distance!) ?? 0;
      if (distanceInMeters < 1000) {
        return '${distanceInMeters}m';
      } else {
        return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
      }
    } catch (e) {
      print('❌ formattedDistance 에러: $e');
      return '';
    }
  }

  // Firestore 데이터로부터 생성
  factory Restaurant.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Restaurant(
      id: documentId,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] as String? ?? '',
      phone: data['phone'] as String?,
      url: data['url'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      distance: data['distance'] as String?,
      city: data['city'] as String?,
      province: data['province'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as dynamic).toDate() as DateTime?
          : null,
      imageUrl: data['imageUrl'] as String?,
      youtubeStats: data['youtubeStats'] != null 
          ? YoutubeStats.fromMap(data['youtubeStats'] as Map<String, dynamic>)
          : null,
      featureTags: data['featureTags'] != null 
          ? List<String>.from(data['featureTags'] as List)
          : null,
      trendScore: data['trendScore'] != null 
          ? TrendScore.fromMap(data['trendScore'] as Map<String, dynamic>)
          : null,
      googlePlaces: data['googlePlaces'] != null 
          ? GooglePlacesData.fromMap(data['googlePlaces'] as Map<String, dynamic>)
          : null,
    );
  }

  // Firestore 저장용 데이터 변환
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'phone': phone,
      'url': url,
      'rating': rating,
      'distance': distance,
      'city': city,
      'province': province,
      'isActive': isActive ?? true,
      'updatedAt': updatedAt,
      'imageUrl': imageUrl,
      'youtubeStats': youtubeStats?.toMap(),
      'featureTags': featureTags,
      'trendScore': trendScore?.toMap(),
      'googlePlaces': googlePlaces?.toMap(),
    };
  }
}