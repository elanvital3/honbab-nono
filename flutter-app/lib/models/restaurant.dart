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
    };
  }
}