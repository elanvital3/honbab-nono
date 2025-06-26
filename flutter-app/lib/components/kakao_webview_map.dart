import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KakaoWebViewMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int level;
  final List<MapMarker>? markers;

  const KakaoWebViewMap({
    super.key,
    this.latitude = 37.5665,
    this.longitude = 126.9780,
    this.level = 10,
    this.markers,
  });

  @override
  State<KakaoWebViewMap> createState() => _KakaoWebViewMapState();
}

class _KakaoWebViewMapState extends State<KakaoWebViewMap> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('🔄 지도 로딩 진행률: $progress%');
          },
          onPageStarted: (String url) {
            print('🚀 지도 페이지 로딩 시작: $url');
          },
          onPageFinished: (String url) {
            print('✅ 지도 페이지 로딩 완료: $url');
            // 페이지 로딩 완료 후 JavaScript 실행 상태 확인
            _checkJavaScriptExecution();
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ 지도 리소스 로딩 에러: ${error.description} (${error.errorType})');
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
        content: '<div style="padding:5px;">${marker.title}</div>'
      });
      
      kakao.maps.event.addListener(marker${marker.id}, 'click', function() {
        infowindow${marker.id}.open(map, marker${marker.id});
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
                
                $markersJs
                
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
    return WebViewWidget(controller: _controller);
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