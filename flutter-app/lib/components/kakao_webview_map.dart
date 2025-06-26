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

  const KakaoWebViewMap({
    super.key,
    this.latitude = 37.5665,
    this.longitude = 126.9780,
    this.level = 10,
    this.markers,
    this.onMarkerClicked,
  });

  @override
  State<KakaoWebViewMap> createState() => _KakaoWebViewMapState();
}

class _KakaoWebViewMapState extends State<KakaoWebViewMap> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(KakaoWebViewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 마커 데이터가 변경되면 JavaScript로 마커 업데이트
    if (oldWidget.markers != widget.markers) {
      _updateMarkers();
    }
  }
  
  void _updateMarkers() {
    final markersData = widget.markers?.map((marker) => {
      'id': marker.id,
      'latitude': marker.latitude,
      'longitude': marker.longitude,
      'title': marker.title,
    }).toList() ?? [];
    
    final markersJson = markersData.map((m) => 
      '{"id":"${m['id']}", "latitude":${m['latitude']}, "longitude":${m['longitude']}, "title":"${m['title']}"}'
    ).join(',');
    
    _controller.runJavaScript('''
      updateMarkers([$markersJson]);
    ''');
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
      var marker${marker.id} = new kakao.maps.Marker({
        position: new kakao.maps.LatLng(${marker.latitude}, ${marker.longitude}),
        map: map
      });
      
      var infowindow${marker.id} = new kakao.maps.InfoWindow({
        content: '<div onclick="MarkerClick.postMessage(&quot;${marker.id}&quot;)" style="padding:6px 16px; background:white; border:none; font-size:12px; white-space:nowrap; cursor:pointer; text-align:center;">' +
                 '<span style="font-weight:600; color:#333;">${marker.title.split(' (')[0]} </span>' +
                 '<span style="font-weight:bold; color:#D2B48C;">(${(marker.title.split(' (').length > 1 ? marker.title.split(' (')[1].replaceAll(')', '') : '')})</span>' +
                 '</div>',
        removable: false
      });
      
      // 마커 생성과 동시에 인포윈도우 표시
      infowindow${marker.id}.open(map, marker${marker.id});
      
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
                
                // 마커 업데이트 함수
                window.updateMarkers = function(newMarkers) {
                  // 기존 마커와 인포윈도우 제거
                  window.currentMarkers.forEach(function(marker) {
                    marker.setMap(null);
                  });
                  window.currentInfoWindows.forEach(function(infoWindow) {
                    infoWindow.close();
                  });
                  window.currentMarkers = [];
                  window.currentInfoWindows = [];
                  
                  // 새로운 마커 생성
                  newMarkers.forEach(function(markerData) {
                    var marker = new kakao.maps.Marker({
                      position: new kakao.maps.LatLng(markerData.latitude, markerData.longitude),
                      map: window.mapInstance
                    });
                    
                    var restaurantName = markerData.title.split(' (')[0];
                    var participantInfo = markerData.title.split(' (').length > 1 ? 
                      '(' + markerData.title.split(' (')[1].replace(')', '') + ')' : '';
                    
                    var infoWindow = new kakao.maps.InfoWindow({
                      content: '<div onclick="MarkerClick.postMessage(&quot;' + markerData.id + '&quot;)" style="padding:6px 16px; background:white; border:none; font-size:12px; white-space:nowrap; cursor:pointer; text-align:center;">' +
                               '<span style="font-weight:600; color:#333;">' + restaurantName + ' </span>' +
                               '<span style="font-weight:bold; color:#D2B48C;">' + participantInfo + '</span>' +
                               '</div>',
                      removable: false
                    });
                    
                    infoWindow.open(window.mapInstance, marker);
                    
                    kakao.maps.event.addListener(marker, 'click', function() {
                      MarkerClick.postMessage(markerData.id);
                    });
                    
                    window.currentMarkers.push(marker);
                    window.currentInfoWindows.push(infoWindow);
                  });
                };
                
                // 초기 마커 설정
                var initialMarkers = [${widget.markers?.map((marker) => '{"id":"${marker.id}", "latitude":${marker.latitude}, "longitude":${marker.longitude}, "title":"${marker.title}"}').join(',')}];
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

  MapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
  });
}