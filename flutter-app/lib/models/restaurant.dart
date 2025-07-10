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

  static int _parseIntFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  factory YoutubeStats.fromMap(Map<String, dynamic> data) {
    return YoutubeStats(
      mentionCount: _parseIntFromDynamic(data['mentionCount']),
      channels: List<String>.from(data['channels'] as List? ?? []),
      firstMentionDate: data['firstMentionDate'] as String?,
      lastMentionDate: data['lastMentionDate'] as String?,
      recentMentions: _parseIntFromDynamic(data['recentMentions']),
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

  static int _parseIntFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  factory RepresentativeVideo.fromMap(Map<String, dynamic> data) {
    return RepresentativeVideo(
      title: data['title'] as String? ?? '',
      channelName: data['channelName'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      viewCount: _parseIntFromDynamic(data['viewCount']),
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

// 네이버 블로그 포스트 정보
class NaverBlogPost {
  final String title;
  final String description;
  final String link;
  final String bloggerName;
  final String bloggerLink;
  final String postDate;

  NaverBlogPost({
    required this.title,
    required this.description,
    required this.link,
    required this.bloggerName,
    required this.bloggerLink,
    required this.postDate,
  });

  factory NaverBlogPost.fromMap(Map<String, dynamic> data) {
    try {
      return NaverBlogPost(
        title: _cleanString(data['title']),
        description: _cleanString(data['description']),
        link: data['link'] as String? ?? '',
        bloggerName: data['bloggername'] as String? ?? '',
        bloggerLink: '', // Fixed: bloggerlink 필드가 Firestore에 없으므로 빈 문자열로 설정
        postDate: data['postdate'] as String? ?? '',
      );
    } catch (e) {
      print('❌ NaverBlogPost.fromMap 에러: $e');
      print('📄 문제되는 블로그 데이터: $data');
      // 에러 발생 시 기본값으로 반환
      return NaverBlogPost(
        title: '제목 불러오기 실패',
        description: '설명 불러오기 실패',
        link: '',
        bloggerName: '알 수 없음',
        bloggerLink: '',
        postDate: '',
      );
    }
  }

  static String _cleanString(dynamic value) {
    if (value == null) return '';
    String str = value.toString();
    // HTML 태그 제거
    str = str.replaceAll(RegExp(r'<[^>]*>'), '');
    // 유효하지 않은 UTF-8 문자 제거
    str = String.fromCharCodes(str.runes.where((r) => r != 0xFFFD));
    return str;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'link': link,
      'bloggername': bloggerName,
      'bloggerlink': bloggerLink,
      'postdate': postDate,
    };
  }
}

// 네이버 블로그 데이터 정보
class NaverBlogData {
  final int totalCount;
  final List<NaverBlogPost> posts;
  final DateTime? updatedAt;

  NaverBlogData({
    required this.totalCount,
    required this.posts,
    this.updatedAt,
  });

  factory NaverBlogData.fromMap(Map<String, dynamic> data) {
    return NaverBlogData(
      totalCount: data['totalCount'] as int? ?? 0,
      posts: (data['blogs'] as List? ?? [])  // Fixed: changed from 'posts' to 'blogs'
          .map((post) => NaverBlogPost.fromMap(post as Map<String, dynamic>))
          .toList(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as dynamic).toDate() as DateTime?
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCount': totalCount,
      'posts': posts.map((post) => post.toMap()).toList(),
      'updatedAt': updatedAt,
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

  static int? _parseIntFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  factory GooglePlacesData.fromMap(Map<String, dynamic> data) {
    try {
      print('🔍 GooglePlaces 전체 데이터 키들: ${data.keys.toList()}');
      print('🔍 rating 값: ${data['rating']} (타입: ${data['rating'].runtimeType})');
      print('🔍 userRatingsTotal 값: ${data['userRatingsTotal']} (타입: ${data['userRatingsTotal'].runtimeType})');
      
      return GooglePlacesData(
        placeId: data['placeId'] as String?,
        rating: (data['rating'] as num?)?.toDouble(),
        userRatingsTotal: _parseIntFromDynamic(data['userRatingsTotal']) ?? 0,
        reviews: (data['reviews'] as List? ?? [])
            .map((review) => GoogleReview.fromMap(review as Map<String, dynamic>))
            .toList(), // 🔥 실제 리뷰 데이터 파싱!
        photos: (data['photos'] as List? ?? [])
            .map((photo) => photo is String ? photo : (photo['photo_reference'] ?? ''))
            .where((photo) => photo.isNotEmpty)
            .cast<String>()
            .toList(),
        priceLevel: _parseIntFromDynamic(data['priceLevel']),
        isOpen: data['isOpen'] as bool?,
        phoneNumber: data['phoneNumber'] as String?,
        regularOpeningHours: data['regularOpeningHours'] as Map<String, dynamic>?,
        updatedAt: data['updatedAt'] != null 
            ? (data['updatedAt'] as dynamic).toDate() as DateTime?
            : null,
      );
    } catch (e) {
      print('❌ GooglePlacesData.fromMap 에러: $e');
      print('📄 문제되는 GooglePlaces 데이터: $data');
      rethrow;
    }
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
      rating: GooglePlacesData._parseIntFromDynamic(data['rating']) ?? 5,
      text: data['text'] as String? ?? '',
      time: GooglePlacesData._parseIntFromDynamic(data['time']) ?? 0,
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
    try {
      // time이 0이면 기본값 반환
      if (time == 0) {
        return '날짜 불명';
      }
      
      DateTime date;
      
      // Google Places API time 필드 처리
      // 먼저 초 단위로 시도 (일반적인 Unix timestamp)
      date = DateTime.fromMillisecondsSinceEpoch(time * 1000);
      
      // 결과가 이상하면 밀리초 단위로 시도
      final now = DateTime.now();
      if (date.year < 2000 || date.year > now.year + 1) {
        date = DateTime.fromMillisecondsSinceEpoch(time);
      }
      
      // 여전히 이상하면 기본값 반환
      if (date.year < 2000 || date.year > now.year + 1) {
        return '날짜 불명';
      }
      
      final difference = now.difference(date);

      // 미래 날짜면 '최근'으로 처리
      if (difference.isNegative) {
        return '최근';
      }

      // 날짜별 포맷팅
      if (difference.inDays < 1) {
        return '오늘';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else if (difference.inDays < 30) {
        return '${difference.inDays ~/ 7}주 전';
      } else if (difference.inDays < 365) {
        return '${difference.inDays ~/ 30}개월 전';
      } else {
        final years = difference.inDays ~/ 365;
        return '${years}년 전';
      }
    } catch (e) {
      print('⚠️ 리뷰 날짜 파싱 오류: $e, time: $time');
      return '날짜 불명';
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

  static int _parseIntFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  factory TrendScore.fromMap(Map<String, dynamic> data) {
    return TrendScore(
      hotness: _parseIntFromDynamic(data['hotness']),
      consistency: _parseIntFromDynamic(data['consistency']),
      isRising: data['isRising'] as bool? ?? false,
      recentMentions: _parseIntFromDynamic(data['recentMentions']),
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
  
  // 네이버 블로그 데이터 필드들
  final NaverBlogData? naverBlog;
  
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
    this.naverBlog,
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

  // GooglePlaces 안전 파싱
  static GooglePlacesData? _parseGooglePlaces(dynamic googlePlacesData) {
    try {
      if (googlePlacesData == null) return null;
      
      print('🔍 GooglePlaces 파싱 시작: ${googlePlacesData.runtimeType}');
      print('   값: $googlePlacesData');
      
      if (googlePlacesData is Map<String, dynamic>) {
        return GooglePlacesData.fromMap(googlePlacesData);
      } else {
        print('❌ GooglePlaces가 Map이 아님: ${googlePlacesData.runtimeType}');
        return null;
      }
    } catch (e) {
      print('❌ GooglePlaces 파싱 에러: $e');
      return null;
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
      featureTags: data['tags'] != null 
          ? List<String>.from(data['tags'] as List)
          : null,
      trendScore: data['trendScore'] != null 
          ? TrendScore.fromMap(data['trendScore'] as Map<String, dynamic>)
          : null,
      googlePlaces: _parseGooglePlaces(data['googlePlaces']),
      naverBlog: data['naverBlog'] != null 
          ? NaverBlogData.fromMap(data['naverBlog'] as Map<String, dynamic>)
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
      'naverBlog': naverBlog?.toMap(),
    };
  }
}