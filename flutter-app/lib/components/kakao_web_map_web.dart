import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

class KakaoWebMap extends StatefulWidget {
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
  State<KakaoWebMap> createState() => _KakaoWebMapState();
}

class _KakaoWebMapState extends State<KakaoWebMap> {
  final String _mapId = 'kakao-map-${DateTime.now().millisecondsSinceEpoch}';
  bool _isMapLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeWebMap();
    }
  }

  void _initializeWebMap() {
    // HTML div 요소 생성
    final mapDiv = html.DivElement()
      ..id = _mapId
      ..style.width = '100%'
      ..style.height = '100%';

    // Flutter 위젯에 HTML 요소 등록
    ui_web.platformViewRegistry.registerViewFactory(_mapId, (int viewId) {
      return mapDiv;
    });

    // 지도 초기화를 위한 스크립트 로드
    _loadKakaoMapScript();
  }

  void _loadKakaoMapScript() {
    // window.kakaoMapReady 플래그 확인 (index.html에서 설정)
    final kakaoReady = js.context['kakaoMapReady'] ?? false;
    if (kakaoReady && js.context.hasProperty('kakao')) {
      print('✅ 카카오맵 SDK 이미 로드됨 (웹)');
      _initializeMap();
      return;
    }

    // SDK 로딩을 위한 재시도 로직 (더 긴 간격으로)
    int retryCount = 0;
    const maxRetries = 15;
    
    void checkSDKLoaded() {
      final ready = js.context['kakaoMapReady'] ?? false;
      final hasKakao = js.context.hasProperty('kakao');
      
      print('🔍 SDK 상태 체크: ready=$ready, hasKakao=$hasKakao');
      
      if (ready && hasKakao) {
        print('✅ 카카오맵 SDK 로드 완료 (웹) - 재시도 $retryCount회');
        _initializeMap();
      } else if (retryCount < maxRetries) {
        retryCount++;
        print('🔄 카카오맵 SDK 대기 중... ($retryCount/$maxRetries)');
        Future.delayed(const Duration(milliseconds: 1000), checkSDKLoaded);
      } else {
        print('❌ 카카오맵 SDK 로드 실패 (웹) - 최대 재시도 초과');
        print('   ready: $ready, hasKakao: $hasKakao');
        setState(() {
          _isMapLoaded = false;
        });
      }
    }
    
    checkSDKLoaded();
  }

  void _initializeMap() {
    // 공식 가이드 방식으로 간소화된 지도 초기화
    js.context.callMethod('eval', ['''
      console.log('카카오맵 초기화 시작 (웹)');
      
      var container = document.getElementById('$_mapId');
      if (!container) {
        console.error('지도 컨테이너를 찾을 수 없습니다: $_mapId');
        return;
      }
      
      var options = {
        center: new kakao.maps.LatLng(${widget.latitude}, ${widget.longitude}),
        level: ${widget.level}
      };
      
      try {
        var map = new kakao.maps.Map(container, options);
        console.log('✅ 카카오맵 생성 완료 (웹)');
        
        // 마커 추가
        ${_generateMarkersScript()}
        
        // Flutter로 로딩 완료 알림
        window.flutter_kakao_map_loaded = true;
      } catch (error) {
        console.error('❌ 카카오맵 생성 실패:', error);
        window.flutter_kakao_map_error = error.message;
      }
    ''']);

    // 로딩 상태 확인을 위한 타이머
    Future.delayed(const Duration(seconds: 3), () {
      final isLoaded = js.context['flutter_kakao_map_loaded'] ?? false;
      final error = js.context['flutter_kakao_map_error'];
      
      setState(() {
        _isMapLoaded = isLoaded;
      });
      
      if (error != null) {
        print('❌ 카카오맵 에러: $error');
      }
    });
  }

  String _generateMarkersScript() {
    if (widget.markers == null || widget.markers!.isEmpty) {
      return '';
    }

    final markersScript = widget.markers!.map((marker) => '''
      var marker${marker.id} = new kakao.maps.Marker({
        position: new kakao.maps.LatLng(${marker.latitude}, ${marker.longitude}),
        map: map
      });
      
      var infowindow${marker.id} = new kakao.maps.InfoWindow({
        content: '<div style="padding:5px; font-size:12px;">${marker.title}</div>'
      });
      
      kakao.maps.event.addListener(marker${marker.id}, 'click', function() {
        infowindow${marker.id}.open(map, marker${marker.id});
      });
    ''').join('\n');

    return markersScript;
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(
        child: Text('웹 전용 컴포넌트입니다'),
      );
    }

    return Stack(
      children: [
        // 카카오맵 HTML 요소
        HtmlElementView(viewType: _mapId),
        
        // 로딩 인디케이터
        if (!_isMapLoaded)
          Container(
            color: Colors.white.withOpacity(0.8),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '카카오맵 로딩 중... (웹)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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