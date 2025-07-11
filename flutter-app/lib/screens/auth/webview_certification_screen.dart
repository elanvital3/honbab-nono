import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../../services/certification_service.dart';
import '../../models/certification_result.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';

class WebViewCertificationScreen extends StatefulWidget {
  final String? name;
  final String? phone;
  final Function(CertificationResult) onResult;

  const WebViewCertificationScreen({
    super.key,
    this.name,
    this.phone,
    required this.onResult,
  });

  @override
  State<WebViewCertificationScreen> createState() => _WebViewCertificationScreenState();
}

class _WebViewCertificationScreenState extends State<WebViewCertificationScreen> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (kDebugMode) {
              print('🔗 페이지 로드 시작: $url');
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            if (kDebugMode) {
              print('✅ 페이지 로드 완료: $url');
            }
            
            // 페이지 로드 후 약간의 딜레이를 두고 JavaScript 실행 확인
            Future.delayed(const Duration(milliseconds: 500), () {
              _checkJavaScriptExecution();
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (kDebugMode) {
              print('🔗 네비게이션 요청: ${request.url}');
            }
            
            // Flutter 커스텀 스키마 처리
            if (request.url.startsWith('flutter://certification_result')) {
              _handleCertificationResult(request.url);
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView 에러: ${error.description}');
            }
            _returnError('페이지 로딩 중 오류가 발생했습니다: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'certification_result',
        onMessageReceived: (JavaScriptMessage message) {
          if (kDebugMode) {
            print('📥 JavaScript 메시지 수신: ${message.message}');
          }
          _handleCertificationResultFromJS(message.message);
        },
      );

    // HTML 로드 (테스트 모드로 시작)
    final htmlContent = CertificationService.createCertificationHTML(
      name: widget.name,
      phone: widget.phone,
      isTestMode: true, // 테스트 모드
    );
    
    if (kDebugMode) {
      print('🌐 HTML 콘텐츠 로딩 시작');
    }
    
    _controller.loadHtmlString(htmlContent);
  }

  void _checkJavaScriptExecution() async {
    try {
      if (kDebugMode) {
        print('🔍 JavaScript 실행 상태 확인 중...');
      }
      
      // 간단한 JavaScript 실행 테스트
      await _controller.runJavaScript('console.log("Flutter에서 JavaScript 실행 테스트");');
      
      if (kDebugMode) {
        print('✅ JavaScript 실행 가능');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ JavaScript 실행 실패: $e');
      }
      _returnError('JavaScript 실행에 문제가 있습니다');
    }
  }

  void _handleCertificationResult(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      
      if (kDebugMode) {
        print('📋 URL에서 인증 결과 파싱: $params');
      }
      
      _processCertificationResult(params);
    } catch (e) {
      if (kDebugMode) {
        print('❌ URL 파싱 오류: $e');
      }
      _returnError('인증 결과 처리 중 오류가 발생했습니다');
    }
  }

  void _handleCertificationResultFromJS(String message) {
    try {
      if (kDebugMode) {
        print('📋 JavaScript에서 인증 결과 파싱: $message');
      }
      
      Map<String, String> params;
      
      // JSON 문자열인지 확인
      if (message.trim().startsWith('{') && message.trim().endsWith('}')) {
        // JSON 파싱
        try {
          final Map<String, dynamic> jsonData = jsonDecode(message);
          
          // String 맵으로 변환
          params = jsonData.map((key, value) => MapEntry(key, value?.toString() ?? ''));
          
          if (kDebugMode) {
            print('✅ JSON 파싱 성공: $params');
          }
          
          // 테스트 모드 전환 요청 감지
          if (params['error_msg']?.contains('테스트 모드 전환 요청') == true) {
            if (kDebugMode) {
              print('🧪 테스트 모드 전환 감지 - 테스트 모드로 재시작');
            }
            _switchToTestMode();
            return;
          }
          
        } catch (e) {
          if (kDebugMode) {
            print('❌ JSON 파싱 실패: $e');
          }
          _returnError('JSON 파싱 중 오류가 발생했습니다');
          return;
        }
      } else {
        // URL 쿼리 스트링 형태로 파싱
        try {
          params = Uri.splitQueryString(message);
        } catch (e) {
          if (kDebugMode) {
            print('❌ URL 파싱 실패: $e');
          }
          _returnError('데이터 파싱 중 오류가 발생했습니다');
          return;
        }
      }
      
      if (kDebugMode) {
        print('📋 파싱된 결과: $params');
      }
      
      _processCertificationResult(params);
    } catch (e) {
      if (kDebugMode) {
        print('❌ JavaScript 메시지 파싱 오류: $e');
      }
      _returnError('인증 결과 처리 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _processCertificationResult(Map<String, String> params) async {
    try {
      if (kDebugMode) {
        print('🔄 WebView: 인증 결과 처리 시작');
      }
      
      // 인증 결과 검증
      final certResult = await CertificationService.verifyCertification(params);
      
      if (mounted) {
        if (kDebugMode) {
          print('📤 WebView: 결과를 부모로 전달 후 화면 닫기');
          print('  - certResult: $certResult');
        }
        
        // 결과를 부모에 전달
        widget.onResult(certResult);
        
        // WebView 화면 닫기
        Navigator.of(context).pop();
        
        if (kDebugMode) {
          print('✅ WebView: Navigator.pop() 완료');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ WebView: mounted=false, 위젯이 이미 제거됨');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ WebView: 인증 결과 처리 오류: $e');
      }
      _returnError('인증 결과 검증 중 오류가 발생했습니다');
    }
  }

  void _switchToTestMode() {
    if (kDebugMode) {
      print('🧪 테스트 모드로 전환 중...');
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // 테스트 모드 HTML로 다시 로드
    final testHtml = CertificationService.createCertificationHTML(
      name: widget.name,
      phone: widget.phone,
      isTestMode: true, // 테스트 모드 활성화
    );
    
    if (kDebugMode) {
      print('🧪 테스트 모드 HTML 로딩 시작');
      print('HTML 길이: ${testHtml.length} 문자');
    }
    
    _controller.loadHtmlString(testHtml);
  }

  void _returnError(String message) {
    if (mounted) {
      final errorResult = CertificationResult(
        success: false,
        isAdult: false,
        errorMessage: message,
      );
      widget.onResult(errorResult);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        title: Text(
          '본인인증',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppDesignTokens.onSurface,
          ),
        ),
        backgroundColor: AppDesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppDesignTokens.onSurface),
          onPressed: () {
            _returnError('사용자가 인증을 취소했습니다');
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: AppDesignTokens.background,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로딩 인디케이터
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppDesignTokens.primary),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      '본인인증 화면 준비 중...',
                      style: AppTextStyles.headlineSmall,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      '잠시만 기다려주세요',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppDesignTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}