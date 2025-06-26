import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewTest extends StatefulWidget {
  const WebViewTest({super.key});

  @override
  State<WebViewTest> createState() => _WebViewTestState();
}

class _WebViewTestState extends State<WebViewTest> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('🔄 테스트 페이지 로딩: $progress%');
          },
          onPageStarted: (String url) {
            print('🚀 테스트 페이지 시작: $url');
          },
          onPageFinished: (String url) {
            print('✅ 테스트 페이지 완료: $url');
            _runJavaScriptTest();
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ 테스트 페이지 에러: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'TestChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('📱 WebView 메시지: ${message.message}');
        },
      )
      ..loadHtmlString(_generateTestHtml());
  }

  void _runJavaScriptTest() async {
    try {
      await _controller.runJavaScript('''
        TestChannel.postMessage('Flutter에서 JavaScript 실행 성공!');
        document.getElementById('result').innerHTML = 'JavaScript 실행됨!';
        document.getElementById('result').style.color = 'green';
      ''');
      print('✅ JavaScript 실행 완료');
    } catch (e) {
      print('❌ JavaScript 실행 실패: $e');
    }
  }

  String _generateTestHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>WebView 테스트</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: Arial, sans-serif;
            padding: 20px;
            text-align: center;
        }
        .test-box {
            border: 2px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            margin: 10px 0;
        }
        #result {
            font-size: 18px;
            font-weight: bold;
            color: orange;
        }
        .btn {
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            margin: 5px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <h1>WebView JavaScript 테스트</h1>
    
    <div class="test-box">
        <h3>1. 기본 JavaScript 실행</h3>
        <div id="result">JavaScript 대기 중...</div>
    </div>
    
    <div class="test-box">
        <h3>2. 외부 스크립트 로딩 테스트</h3>
        <div id="external-result">외부 스크립트 대기 중...</div>
    </div>
    
    <div class="test-box">
        <h3>3. 버튼 클릭 테스트</h3>
        <button class="btn" onclick="testClick()">클릭 테스트</button>
        <div id="click-result"></div>
    </div>
    
    <div class="test-box">
        <h3>4. 네트워크 연결 테스트</h3>
        <div id="network-result">네트워크 테스트 중...</div>
    </div>
    
    <div class="test-box">
        <h3>5. 카카오맵 SDK 테스트</h3>
        <div id="kakao-result">카카오 SDK 테스트 중...</div>
    </div>

    <script>
        // 기본 JavaScript 테스트
        TestChannel.postMessage('HTML 로딩 완료');
        
        // 외부 스크립트 테스트 (jQuery)
        function loadExternalScript() {
            var script = document.createElement('script');
            script.src = 'https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js';
            script.onload = function() {
                document.getElementById('external-result').innerHTML = '✅ jQuery 로딩 성공';
                document.getElementById('external-result').style.color = 'green';
                TestChannel.postMessage('jQuery 로딩 성공');
            };
            script.onerror = function() {
                document.getElementById('external-result').innerHTML = '❌ jQuery 로딩 실패';
                document.getElementById('external-result').style.color = 'red';
                TestChannel.postMessage('jQuery 로딩 실패');
            };
            document.head.appendChild(script);
        }
        
        // 클릭 테스트
        function testClick() {
            document.getElementById('click-result').innerHTML = '✅ 클릭 이벤트 작동!';
            document.getElementById('click-result').style.color = 'green';
            TestChannel.postMessage('클릭 이벤트 성공');
        }
        
        // 네트워크 연결 테스트
        function testNetwork() {
            fetch('https://httpbin.org/get')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('network-result').innerHTML = '✅ 네트워크 연결 성공';
                    document.getElementById('network-result').style.color = 'green';
                    TestChannel.postMessage('네트워크 연결 성공');
                })
                .catch(error => {
                    document.getElementById('network-result').innerHTML = '❌ 네트워크 연결 실패';
                    document.getElementById('network-result').style.color = 'red';
                    TestChannel.postMessage('네트워크 연결 실패: ' + error.message);
                });
        }
        
        // 카카오맵 SDK 테스트
        function testKakaoSDK() {
            TestChannel.postMessage('카카오 SDK 테스트 시작');
            
            var script = document.createElement('script');
            script.type = 'text/javascript';
            script.src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=72f1d70089c36f4a8c9fabe7dc6be080&autoload=false';
            
            script.onload = function() {
                TestChannel.postMessage('✅ 카카오 SDK 스크립트 로드 성공');
                document.getElementById('kakao-result').innerHTML = '✅ SDK 로드 성공';
                document.getElementById('kakao-result').style.color = 'green';
                
                try {
                    if (typeof kakao !== 'undefined') {
                        TestChannel.postMessage('✅ kakao 객체 확인됨');
                        
                        kakao.maps.load(function() {
                            TestChannel.postMessage('✅ kakao.maps.load 성공');
                            document.getElementById('kakao-result').innerHTML = '✅ 카카오맵 SDK 완전 로드 성공!';
                        });
                    } else {
                        TestChannel.postMessage('❌ kakao 객체 없음');
                        document.getElementById('kakao-result').innerHTML = '❌ kakao 객체 없음';
                        document.getElementById('kakao-result').style.color = 'red';
                    }
                } catch (error) {
                    TestChannel.postMessage('❌ 카카오 SDK 초기화 에러: ' + error.message);
                    document.getElementById('kakao-result').innerHTML = '❌ 초기화 에러: ' + error.message;
                    document.getElementById('kakao-result').style.color = 'red';
                }
            };
            
            script.onerror = function() {
                TestChannel.postMessage('❌ 카카오 SDK 스크립트 로드 실패');
                document.getElementById('kakao-result').innerHTML = '❌ SDK 로드 실패';
                document.getElementById('kakao-result').style.color = 'red';
            };
            
            document.head.appendChild(script);
        }
        
        // 페이지 로드 후 실행
        window.onload = function() {
            TestChannel.postMessage('window.onload 실행됨');
            loadExternalScript();
            testNetwork();
            setTimeout(testKakaoSDK, 2000); // 2초 후 카카오 SDK 테스트
        };
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebView 테스트'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}