import 'package:cloud_firestore/cloud_firestore.dart';

class ExternalRating {
  final double score;
  final int reviewCount;
  final String url;

  ExternalRating({
    required this.score,
    required this.reviewCount,
    required this.url,
  });

  factory ExternalRating.fromJson(Map<String, dynamic> json) {
    return ExternalRating(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'reviewCount': reviewCount,
      'url': url,
    };
  }
}

class DeepLinks {
  final String? naver;
  final String? kakao;

  DeepLinks({
    this.naver,
    this.kakao,
  });

  factory DeepLinks.fromJson(Map<String, dynamic> json) {
    return DeepLinks(
      naver: json['naver'] as String?,
      kakao: json['kakao'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'naver': naver,
      'kakao': kakao,
    };
  }
}

class RestaurantRating {
  final String restaurantId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final ExternalRating? naverRating;
  final ExternalRating? kakaoRating;
  final String category;
  final DateTime lastUpdated;
  final DateTime createdAt;
  final DeepLinks deepLinks;

  RestaurantRating({
    required this.restaurantId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.naverRating,
    this.kakaoRating,
    required this.category,
    required this.lastUpdated,
    required this.createdAt,
    required this.deepLinks,
  });

  factory RestaurantRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RestaurantRating(
      restaurantId: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      naverRating: data['naverRating'] != null 
          ? ExternalRating.fromJson(data['naverRating'] as Map<String, dynamic>)
          : null,
      kakaoRating: data['kakaoRating'] != null 
          ? ExternalRating.fromJson(data['kakaoRating'] as Map<String, dynamic>)
          : null,
      category: data['category'] as String? ?? '',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deepLinks: data['deepLinks'] != null 
          ? DeepLinks.fromJson(data['deepLinks'] as Map<String, dynamic>)
          : DeepLinks(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'naverRating': naverRating?.toJson(),
      'kakaoRating': kakaoRating?.toJson(),
      'category': category,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'createdAt': Timestamp.fromDate(createdAt),
      'deepLinks': deepLinks.toJson(),
    };
  }

  // 가장 높은 평점 반환 (네이버/카카오 중)
  ExternalRating? get bestRating {
    if (naverRating == null && kakaoRating == null) return null;
    if (naverRating == null) return kakaoRating;
    if (kakaoRating == null) return naverRating;
    
    return naverRating!.score >= kakaoRating!.score ? naverRating : kakaoRating;
  }

  // 평점이 있는지 확인
  bool get hasRating => naverRating != null || kakaoRating != null;

  // 평점 표시용 문자열
  String get ratingDisplay {
    final best = bestRating;
    if (best == null) return '';
    
    final source = best == naverRating ? '네이버' : '카카오';
    return '$source ${best.score.toStringAsFixed(1)}★';
  }

  // 리뷰 수 표시용 문자열
  String get reviewCountDisplay {
    final best = bestRating;
    if (best == null) return '';
    
    return '리뷰 ${best.reviewCount}개';
  }
}