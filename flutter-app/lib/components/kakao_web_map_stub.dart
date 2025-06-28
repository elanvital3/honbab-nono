import 'package:flutter/material.dart';

class KakaoWebMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final int level;
  final List<WebMapMarker>? markers;

  const KakaoWebMap({
    super.key,
    this.latitude = 37.5665,
    this.longitude = 126.9780,
    this.level = 10,
    this.markers,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('모바일에서는 WebView 방식을 사용합니다'),
    );
  }
}

class WebMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? color;
  final double? rating;

  WebMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.color,
    this.rating,
  });
}