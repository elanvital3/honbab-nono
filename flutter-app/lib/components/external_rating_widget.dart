import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant_rating.dart';
import '../services/restaurant_rating_service.dart';
import '../models/restaurant.dart';

/// 외부 평점 표시 위젯
/// 네이버/카카오 평점을 표시하고 딥링크 연결 제공
class ExternalRatingWidget extends StatefulWidget {
  final Restaurant restaurant;
  final bool showLoadingIndicator;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;

  const ExternalRatingWidget({
    super.key,
    required this.restaurant,
    this.showLoadingIndicator = true,
    this.padding,
    this.iconSize = 16,
  });

  @override
  State<ExternalRatingWidget> createState() => _ExternalRatingWidgetState();
}

class _ExternalRatingWidgetState extends State<ExternalRatingWidget> {
  RestaurantRating? _rating;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    print('🔍 평점 로딩 시작: ${widget.restaurant.name}');
    
    if (!widget.showLoadingIndicator) {
      print('⚠️ showLoadingIndicator=false이므로 평점 로딩 스킵');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('📊 RestaurantRatingService.findMatchingRating 호출 중...');
      final rating = await RestaurantRatingService.findMatchingRating(widget.restaurant);
      
      if (rating != null) {
        print('✅ 평점 발견: ${rating.name}, 네이버: ${rating.naverRating?.score}, 카카오: ${rating.kakaoRating?.score}');
      } else {
        print('❌ 평점 없음: ${widget.restaurant.name}');
      }
      
      if (mounted) {
        setState(() {
          _rating = rating;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 평점 로드 오류: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoadingIndicator) {
      return _buildLoadingWidget();
    }

    if (_hasError || _rating == null || !_rating!.hasRating) {
      return const SizedBox.shrink(); // 평점이 없으면 아무것도 표시하지 않음
    }

    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rating!.naverRating != null) 
            _buildRatingRow(
              platform: 'naver',
              rating: _rating!.naverRating!,
              deepLink: _rating!.deepLinks.naver,
            ),
          if (_rating!.naverRating != null && _rating!.kakaoRating != null)
            const SizedBox(height: 4),
          if (_rating!.kakaoRating != null)
            _buildRatingRow(
              platform: 'kakao',
              rating: _rating!.kakaoRating!,
              deepLink: _rating!.deepLinks.kakao,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '평점 확인 중...',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow({
    required String platform,
    required ExternalRating rating,
    String? deepLink,
  }) {
    final platformInfo = _getPlatformInfo(platform);
    
    return InkWell(
      onTap: deepLink != null ? () => _openDeepLink(deepLink) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 플랫폼 아이콘
            Icon(
              platformInfo.icon,
              size: widget.iconSize,
              color: platformInfo.color,
            ),
            const SizedBox(width: 6),
            
            // 평점 표시
            Text(
              '${rating.score.toStringAsFixed(1)}★',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: platformInfo.color,
              ),
            ),
            const SizedBox(width: 4),
            
            // 리뷰 수
            Text(
              '(${_formatReviewCount(rating.reviewCount)})',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            
            // 딥링크가 있으면 화살표 아이콘
            if (deepLink != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  PlatformInfo _getPlatformInfo(String platform) {
    switch (platform) {
      case 'naver':
        return PlatformInfo(
          name: '네이버',
          icon: Icons.map,
          color: const Color(0xFF03C75A), // 네이버 그린
        );
      case 'kakao':
        return PlatformInfo(
          name: '카카오',
          icon: Icons.location_on,
          color: const Color(0xFFFFE812), // 카카오 옐로우
        );
      default:
        return PlatformInfo(
          name: '기타',
          icon: Icons.star,
          color: Theme.of(context).colorScheme.primary,
        );
    }
  }

  String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Future<void> _openDeepLink(String deepLink) async {
    try {
      final uri = Uri.parse(deepLink);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 외부 앱에서 열기
        );
      } else {
        // 딥링크 실패 시 웹 URL로 폴백
        final webUrl = _convertToWebUrl(deepLink);
        if (webUrl != null) {
          final webUri = Uri.parse(webUrl);
          await launchUrl(webUri);
        } else {
          _showErrorSnackBar('앱을 열 수 없습니다');
        }
      }
    } catch (e) {
      print('❌ 딥링크 오픈 오류: $e');
      _showErrorSnackBar('링크를 열 수 없습니다');
    }
  }

  String? _convertToWebUrl(String deepLink) {
    if (deepLink.startsWith('nmap://')) {
      // 네이버 딥링크 → 웹 URL 변환
      final placeId = RegExp(r'id=(\d+)').firstMatch(deepLink)?.group(1);
      if (placeId != null) {
        return 'https://map.naver.com/v5/entry/place/$placeId';
      }
    } else if (deepLink.startsWith('kakaomap://')) {
      // 카카오 딥링크 → 웹 URL 변환
      final placeId = RegExp(r'id=(\d+)').firstMatch(deepLink)?.group(1);
      if (placeId != null) {
        return 'https://place.map.kakao.com/$placeId';
      }
    }
    return null;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 간단한 평점 표시 위젯 (로딩 없이)
class SimpleRatingWidget extends StatelessWidget {
  final RestaurantRating rating;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  const SimpleRatingWidget({
    super.key,
    required this.rating,
    this.iconSize = 16,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!rating.hasRating) {
      return const SizedBox.shrink();
    }

    return ExternalRatingWidget(
      restaurant: Restaurant(
        id: rating.restaurantId,
        name: rating.name,
        address: rating.address,
        latitude: rating.latitude,
        longitude: rating.longitude,
        category: rating.category,
      ),
      showLoadingIndicator: false,
      padding: padding,
      iconSize: iconSize,
    );
  }
}

/// 베스트 평점만 표시하는 위젯
class BestRatingWidget extends StatelessWidget {
  final RestaurantRating rating;
  final double? iconSize;
  final bool showPlatformName;

  const BestRatingWidget({
    super.key,
    required this.rating,
    this.iconSize = 14,
    this.showPlatformName = false,
  });

  @override
  Widget build(BuildContext context) {
    final bestRating = rating.bestRating;
    if (bestRating == null) {
      return const SizedBox.shrink();
    }

    final platform = bestRating == rating.naverRating ? 'naver' : 'kakao';
    final platformInfo = _getPlatformInfo(platform);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: iconSize,
          color: platformInfo.color,
        ),
        const SizedBox(width: 4),
        Text(
          bestRating.score.toStringAsFixed(1),
          style: TextStyle(
            fontSize: iconSize,
            fontWeight: FontWeight.w600,
            color: platformInfo.color,
          ),
        ),
        if (showPlatformName) ...[
          const SizedBox(width: 4),
          Text(
            platformInfo.name,
            style: TextStyle(
              fontSize: iconSize! - 2,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  PlatformInfo _getPlatformInfo(String platform) {
    switch (platform) {
      case 'naver':
        return PlatformInfo(
          name: '네이버',
          icon: Icons.map,
          color: const Color(0xFF03C75A),
        );
      case 'kakao':
        return PlatformInfo(
          name: '카카오',
          icon: Icons.location_on,
          color: const Color(0xFFFFE812),
        );
      default:
        return PlatformInfo(
          name: '기타',
          icon: Icons.star,
          color: Colors.amber,
        );
    }
  }
}

/// 플랫폼 정보 클래스
class PlatformInfo {
  final String name;
  final IconData icon;
  final Color color;

  PlatformInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}