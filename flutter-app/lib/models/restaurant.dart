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
  final String? distance;

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

  String get displayDistance {
    if (distance == null) return '';
    final distanceInMeters = int.tryParse(distance!) ?? 0;
    if (distanceInMeters < 1000) {
      return '${distanceInMeters}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }
}