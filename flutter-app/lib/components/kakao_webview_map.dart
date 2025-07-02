import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KakaoWebViewMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int level;
  final List<MapMarker>? markers;
  final Function(String)? onMarkerClicked;
  final VoidCallback? onMapLoaded;
  final Function(double, double)? onMapMoved;
  final Function(double, double, double, double)? onBoundsChanged;

  const KakaoWebViewMap({
    super.key,
    this.latitude = 37.5665,
    this.longitude = 126.9780,
    this.level = 10,
    this.markers,
    this.onMarkerClicked,
    this.onMapLoaded,
    this.onMapMoved,
    this.onBoundsChanged,
  });

  @override
  State<KakaoWebViewMap> createState() => KakaoWebViewMapState();
}

class KakaoWebViewMapState extends State<KakaoWebViewMap> {
  bool _isMapLoaded = false;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(KakaoWebViewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 마커 데이터가 실제로 변경된 경우에만 업데이트
    if (_isMapLoaded && _hasMarkersChanged(oldWidget.markers, widget.markers)) {
      _updateMarkers();
    }
    
    // 위치가 의미있게 변경된 경우에만 지도 중심 이동 (0.001도 이상 차이)
    if (_isMapLoaded && 
        ((oldWidget.latitude - widget.latitude).abs() > 0.001 || 
         (oldWidget.longitude - widget.longitude).abs() > 0.001)) {
      _updateMapCenter();
    }
  }
  
  bool _hasMarkersChanged(List<MapMarker>? oldMarkers, List<MapMarker>? newMarkers) {
    if (oldMarkers == null && newMarkers == null) return false;
    if (oldMarkers == null || newMarkers == null) return true;
    if (oldMarkers.length != newMarkers.length) return true;
    
    for (int i = 0; i < oldMarkers.length; i++) {
      if (oldMarkers[i].id != newMarkers[i].id ||
          oldMarkers[i].latitude != newMarkers[i].latitude ||
          oldMarkers[i].longitude != newMarkers[i].longitude ||
          oldMarkers[i].title != newMarkers[i].title) {
        return true;
      }
    }
    return false;
  }
  
  void _updateMarkers() {
    final markersData = widget.markers?.map((marker) => {
      'id': marker.id,
      'latitude': marker.latitude,
      'longitude': marker.longitude,
      'title': marker.title,
      'color': marker.color ?? '',
      'rating': marker.rating ?? 0,
    }).toList() ?? [];
    
    final markersJson = markersData.map((m) => 
      '{"id":"${m['id']}", "latitude":${m['latitude']}, "longitude":${m['longitude']}, "title":"${m['title']}", "color":"${m['color']}", "rating":${m['rating']}}'
    ).join(',');
    
    _controller.runJavaScript('''
      updateMarkers([$markersJson]);
    ''');
  }
  
  void _updateMapCenter() {
    _controller.runJavaScript('''
      if (window.mapInstance) {
        var newCenter = new kakao.maps.LatLng(${widget.latitude}, ${widget.longitude});
        window.mapInstance.setCenter(newCenter);
        FlutterLog.postMessage('지도 중심 이동: ${widget.latitude}, ${widget.longitude}');
      }
    ''');
  }
  
  // 외부에서 호출할 수 있는 지도 중심 업데이트 메서드
  void updateMapCenter(double latitude, double longitude) {
    if (_isMapLoaded) {
      _controller.runJavaScript('''
        if (window.mapInstance) {
          var newCenter = new kakao.maps.LatLng($latitude, $longitude);
          window.mapInstance.setCenter(newCenter);
          FlutterLog.postMessage('외부 요청에 의한 지도 중심 이동: $latitude, $longitude');
        }
      ''');
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // 진행률 로그 최소화
            if (progress == 100) print('✅ 지도 로딩 완료');
          },
          onPageStarted: (String url) {
            print('🚀 지도 페이지 로딩 시작');
          },
          onPageFinished: (String url) {
            print('✅ 지도 페이지 로딩 완료');
            _checkJavaScriptExecution();
            if (!_isMapLoaded) {
              _isMapLoaded = true;
              widget.onMapLoaded?.call();
            }
          },
          onWebResourceError: (WebResourceError error) {
            // 에러 로그만 중요한 것만 출력
            if (error.errorType.toString().contains('TIMEOUT') || 
                error.errorType.toString().contains('CONNECTION')) {
              print('❌ 지도 연결 에러: ${error.description}');
            }
          },
        ),
      )
      // JavaScript 콘솔 로그를 Flutter로 전달
      ..addJavaScriptChannel(
        'FlutterLog',
        onMessageReceived: (JavaScriptMessage message) {
          print('🌐 WebView JS: ${message.message}');
        },
      )
      // 마커 클릭 이벤트를 Flutter로 전달
      ..addJavaScriptChannel(
        'MarkerClick',
        onMessageReceived: (JavaScriptMessage message) {
          final meetingId = message.message;
          print('🗺️ 마커 클릭: $meetingId');
          widget.onMarkerClicked?.call(meetingId);
        },
      )
      // 지도 이동 이벤트를 Flutter로 전달
      ..addJavaScriptChannel(
        'MapMove',
        onMessageReceived: (JavaScriptMessage message) {
          final coords = message.message.split(',');
          if (coords.length == 2) {
            final lat = double.tryParse(coords[0]) ?? 0.0;
            final lng = double.tryParse(coords[1]) ?? 0.0;
            widget.onMapMoved?.call(lat, lng);
          }
        },
      )
      // 지도 경계 변경 이벤트를 Flutter로 전달
      ..addJavaScriptChannel(
        'BoundsChange',
        onMessageReceived: (JavaScriptMessage message) {
          final bounds = message.message.split(',');
          if (bounds.length == 4) {
            final swLat = double.tryParse(bounds[0]) ?? 0.0;
            final swLng = double.tryParse(bounds[1]) ?? 0.0;
            final neLat = double.tryParse(bounds[2]) ?? 0.0;
            final neLng = double.tryParse(bounds[3]) ?? 0.0;
            widget.onBoundsChanged?.call(swLat, swLng, neLat, neLng);
          }
        },
      )
      ..loadHtmlString(_generateMapHtml());
  }
  
  void _checkJavaScriptExecution() async {
    try {
      await _controller.runJavaScript('''
        console.log('JavaScript 실행 테스트');
        FlutterLog.postMessage('JavaScript 채널 연결 성공');
      ''');
    } catch (e) {
      print('❌ JavaScript 실행 실패: $e');
    }
  }

  String _generateMapHtml() {
    final markersJs = widget.markers?.map((marker) => '''
      var markerImageSrc${marker.id}, markerImageSize${marker.id}, markerImageOption${marker.id};
      
      // 마커 색상에 따른 이미지 설정 - SVG 기반 커스텀 마커 생성
      var markerImage${marker.id};
      if ('${marker.color ?? ''}' === 'green') {
        // 그린색 SVG 마커 (검색된 식당)
        var svgGreenMarker = 'data:image/svg+xml;base64,' + btoa('<svg width="32" height="40" viewBox="0 0 32 40" xmlns="http://www.w3.org/2000/svg"><path d="M16 0C7.163 0 0 7.163 0 16c0 8.837 16 24 16 24s16-15.163 16-24C32 7.163 24.837 0 16 0z" fill="#4CAF50"/><circle cx="16" cy="16" r="8" fill="white"/><circle cx="16" cy="16" r="5" fill="#2E7D32"/></svg>');
        markerImageSrc${marker.id} = svgGreenMarker;
      } else {
        // 베이지색 SVG 마커 (기존 모임)
        var svgBeigeMarker = 'data:image/svg+xml;base64,' + btoa('<svg width="32" height="40" viewBox="0 0 32 40" xmlns="http://www.w3.org/2000/svg"><path d="M16 0C7.163 0 0 7.163 0 16c0 8.837 16 24 16 24s16-15.163 16-24C32 7.163 24.837 0 16 0z" fill="#D2B48C"/><circle cx="16" cy="16" r="8" fill="white"/><circle cx="16" cy="16" r="5" fill="#8B7355"/></svg>');
        markerImageSrc${marker.id} = svgBeigeMarker;
      }
      
      markerImageSize${marker.id} = new kakao.maps.Size(32, 40);
      markerImageOption${marker.id} = {offset: new kakao.maps.Point(16, 40)};
      
      var markerImage${marker.id} = new kakao.maps.MarkerImage(markerImageSrc${marker.id}, markerImageSize${marker.id}, markerImageOption${marker.id});
      
      var marker${marker.id} = new kakao.maps.Marker({
        position: new kakao.maps.LatLng(${marker.latitude}, ${marker.longitude}),
        image: markerImage${marker.id},
        map: map
      });
      
      // 커스텀 인포박스는 updateMarkers 함수에서 처리됩니다
      
      kakao.maps.event.addListener(marker${marker.id}, 'click', function() {
        // Flutter로 마커 클릭 이벤트 전달
        MarkerClick.postMessage('${marker.id}');
      });
    ''').join('\n') ?? '';

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>카카오맵</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>
        html, body { margin: 0; padding: 0; width: 100%; height: 100%; }
        #map { width: 100%; height: 100%; }
        .loading { 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            height: 100%; 
            font-size: 16px; 
            color: #666; 
        }
        
        /* 커스텀 인포박스 스타일 - 단순화 버전 */
        .custom-infobox {
            cursor: pointer;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            max-width: 150px;
        }
        
        .infobox-title {
            font-size: 12px;
            font-weight: 700;
            color: #333333;
            line-height: 1.1;
            margin-bottom: 2px;
            background: rgba(255, 255, 255, 0.85);
            padding: 4px 8px;
            border-radius: 8px;
            backdrop-filter: blur(4px);
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        
        .infobox-rating {
            font-size: 10px;
            color: #FF9500;
            font-weight: 600;
            background: rgba(255, 255, 255, 0.85);
            padding: 2px 6px;
            border-radius: 6px;
            backdrop-filter: blur(4px);
            border: 1px solid rgba(255, 255, 255, 0.3);
            margin-top: 2px;
        }
        
        /* 그린 마커용 텍스트 색상 */
        .custom-infobox.green .infobox-title {
            color: #2E7D32;
        }
        
        /* 베이지 마커용 텍스트 색상 */
        .custom-infobox.beige .infobox-title {
            color: #8B7355;
        }
    </style>
</head>
<body>
    <div id="map">
        <div class="loading">지도 로딩 중...</div>
    </div>
    
    <script>
        // SDK 로딩 완료 후 실행할 함수
        function initializeMap() {
            try {
                FlutterLog.postMessage('카카오맵 초기화 시작');
                
                if (typeof kakao === 'undefined') {
                    throw new Error('카카오 SDK가 로드되지 않았습니다');
                }
                
                var container = document.getElementById('map');
                var options = {
                    center: new kakao.maps.LatLng(${widget.latitude}, ${widget.longitude}),
                    level: ${widget.level}
                };
                
                var map = new kakao.maps.Map(container, options);
                FlutterLog.postMessage('✅ 카카오맵 생성 완료');
                
                // 전역 변수들
                window.mapInstance = map;
                window.currentMarkers = [];
                window.currentInfoWindows = [];
                window.initialCenter = map.getCenter();
                
                // 지도 이동 이벤트 리스너
                kakao.maps.event.addListener(map, 'dragend', function() {
                    var center = map.getCenter();
                    MapMove.postMessage(center.getLat() + ',' + center.getLng());
                    
                    // 경계 정보도 전달
                    var bounds = map.getBounds();
                    var sw = bounds.getSouthWest();
                    var ne = bounds.getNorthEast();
                    BoundsChange.postMessage(sw.getLat() + ',' + sw.getLng() + ',' + ne.getLat() + ',' + ne.getLng());
                });
                
                // 줌 변경 시에도 경계 정보 전달
                kakao.maps.event.addListener(map, 'zoom_changed', function() {
                    var bounds = map.getBounds();
                    var sw = bounds.getSouthWest();
                    var ne = bounds.getNorthEast();
                    BoundsChange.postMessage(sw.getLat() + ',' + sw.getLng() + ',' + ne.getLat() + ',' + ne.getLng());
                });
                
                // 마커 업데이트 함수
                window.updateMarkers = function(newMarkers) {
                  // 기존 마커와 인포윈도우 제거
                  window.currentMarkers.forEach(function(marker) {
                    marker.setMap(null);
                  });
                  window.currentInfoWindows.forEach(function(overlay) {
                    overlay.setMap(null);
                  });
                  window.currentMarkers = [];
                  window.currentInfoWindows = [];
                  
                  // 새로운 마커 생성
                  newMarkers.forEach(function(markerData) {
                    var markerImageSrc, markerImageSize, markerImageOption;
                    
                    // 마커 색상에 따른 이미지 설정 - SVG 기반 커스텀 마커 생성
                    var markerImage;
                    if (markerData.color === 'green') {
                      // 그린색 SVG 마커 (검색된 식당)
                      var svgGreenMarker = 'data:image/svg+xml;base64,' + btoa('<svg width="32" height="40" viewBox="0 0 32 40" xmlns="http://www.w3.org/2000/svg"><path d="M16 0C7.163 0 0 7.163 0 16c0 8.837 16 24 16 24s16-15.163 16-24C32 7.163 24.837 0 16 0z" fill="#4CAF50"/><circle cx="16" cy="16" r="8" fill="white"/><circle cx="16" cy="16" r="5" fill="#2E7D32"/></svg>');
                      markerImageSrc = svgGreenMarker;
                    } else {
                      // 베이지색 SVG 마커 (기존 모임)
                      var svgBeigeMarker = 'data:image/svg+xml;base64,' + btoa('<svg width="32" height="40" viewBox="0 0 32 40" xmlns="http://www.w3.org/2000/svg"><path d="M16 0C7.163 0 0 7.163 0 16c0 8.837 16 24 16 24s16-15.163 16-24C32 7.163 24.837 0 16 0z" fill="#D2B48C"/><circle cx="16" cy="16" r="8" fill="white"/><circle cx="16" cy="16" r="5" fill="#8B7355"/></svg>');
                      markerImageSrc = svgBeigeMarker;
                    }
                    
                    markerImageSize = new kakao.maps.Size(32, 40);
                    markerImageOption = {offset: new kakao.maps.Point(16, 40)};
                    
                    var markerImage = new kakao.maps.MarkerImage(markerImageSrc, markerImageSize, markerImageOption);
                    
                    var marker = new kakao.maps.Marker({
                      position: new kakao.maps.LatLng(markerData.latitude, markerData.longitude),
                      image: markerImage,
                      map: window.mapInstance
                    });
                    
                    var ratingDisplay = '';
                    if (markerData.rating && markerData.rating > 0) {
                      ratingDisplay = '<div style="font-size:10px; color:#FF9500; margin-top:1px;">⭐ ' + markerData.rating.toFixed(1) + '</div>';
                    }
                    
                    // 커스텀 인포박스 HTML 생성
                    var customContent = document.createElement('div');
                    customContent.className = 'custom-infobox ' + (markerData.color === 'green' ? 'green' : 'beige');
                    customContent.onclick = function() {
                      MarkerClick.postMessage(markerData.id);
                    };
                    
                    customContent.innerHTML = 
                      '<div class="infobox-title">' + markerData.title + '</div>' +
                      (ratingDisplay ? '<div class="infobox-rating">' + ratingDisplay.replace(/<[^>]*>/g, '').replace('⭐ ', '⭐ ') + '</div>' : '');
                    
                    // 커스텀 오버레이 생성 - 마커 상단에 위치 (겹치지 않게)
                    var customOverlay = new kakao.maps.CustomOverlay({
                      content: customContent,
                      position: new kakao.maps.LatLng(markerData.latitude, markerData.longitude),
                      xAnchor: 0.5,
                      yAnchor: 2.2,
                      zIndex: 3
                    });
                    
                    customOverlay.setMap(window.mapInstance);
                    
                    kakao.maps.event.addListener(marker, 'click', function() {
                      MarkerClick.postMessage(markerData.id);
                    });
                    
                    window.currentMarkers.push(marker);
                    window.currentInfoWindows.push(customOverlay);
                  });
                };
                
                // 초기 마커 설정
                var initialMarkers = [${widget.markers?.map((marker) => '{"id":"${marker.id}", "latitude":${marker.latitude}, "longitude":${marker.longitude}, "title":"${marker.title}", "color":"${marker.color ?? ''}", "rating":${marker.rating ?? 0}}').join(',')}];
                window.updateMarkers(initialMarkers);
                
            } catch (error) {
                FlutterLog.postMessage('❌ 카카오맵 에러: ' + error.message);
                document.getElementById('map').innerHTML = 
                    '<div style="padding: 20px; text-align: center; color: red;">지도 로딩 실패: ' + 
                    error.message + '</div>';
            }
        }
        
        // SDK 로딩 및 초기화
        function loadKakaoSDK() {
            FlutterLog.postMessage('카카오 SDK 로딩 시작');
            
            var script = document.createElement('script');
            script.type = 'text/javascript';
            script.src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=72f1d70089c36f4a8c9fabe7dc6be080&autoload=false';
            
            script.onload = function() {
                FlutterLog.postMessage('카카오 SDK 로드 완료');
                // autoload=false이므로 수동으로 로드
                kakao.maps.load(function() {
                    FlutterLog.postMessage('카카오 maps 로드 완료');
                    initializeMap();
                });
            };
            
            script.onerror = function() {
                FlutterLog.postMessage('❌ 카카오 SDK 로드 실패');
                document.getElementById('map').innerHTML = 
                    '<div style="padding: 20px; text-align: center; color: red;">SDK 로드 실패</div>';
            };
            
            document.head.appendChild(script);
        }
        
        // 페이지 로드 완료 후 실행
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', loadKakaoSDK);
        } else {
            loadKakaoSDK();
        }
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: WebViewWidget(
        controller: _controller,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
          Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
        },
      ),
    );
  }
}

class MapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? color;
  final double? rating;

  MapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.color,
    this.rating,
  });
}