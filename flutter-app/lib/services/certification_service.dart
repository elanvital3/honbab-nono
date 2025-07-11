import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/certification_result.dart';

class CertificationService {
  static String get _userCode => dotenv.env['IAMPORT_USER_CODE'] ?? '';
  static String get _restApiKey => dotenv.env['IAMPORT_REST_API_KEY'] ?? '';
  static String get _restApiSecret => dotenv.env['IAMPORT_REST_API_SECRET'] ?? '';
  static String get _storeId => dotenv.env['IAMPORT_STORE_ID'] ?? ''; // V2 API용
  static String get _danalChannelKey => dotenv.env['IAMPORT_DANAL_CHANNEL_KEY'] ?? '';

  /// 성인인증용 HTML 페이지 생성
  static String createCertificationHTML({
    String? name,
    String? phone,
    bool isTestMode = true, // 테스트 모드로 다시 변경!
  }) {
    final merchantUid = 'cert_${DateTime.now().millisecondsSinceEpoch}';
    
    // 테스트 모드일 때는 간단한 테스트 페이지 반환
    if (isTestMode) {
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>본인인증 테스트</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f8f9fa;
        }
        .container {
            text-align: center;
            padding: 50px 20px;
        }
        .button {
            background-color: #D2B48C;
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 8px;
            font-size: 16px;
            margin: 10px;
            cursor: pointer;
        }
        .info {
            margin: 20px 0;
            padding: 15px;
            background: #e3f2fd;
            border-radius: 8px;
            color: #1565c0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>본인인증 테스트</h2>
        <div class="info">
            <p>테스트 모드입니다.</p>
            <p>실제 본인인증 대신 가상의 데이터로 테스트합니다.</p>
        </div>
        
        <button class="button" onclick="simulateSuccess()">성공 시뮬레이션</button>
        <button class="button" onclick="simulateFailure()">실패 시뮬레이션</button>
        <button class="button" onclick="simulateMinor()">미성년자 시뮬레이션</button>
    </div>
    
    <script>
        console.log('🧪 테스트 모드 시작');
        
        function sendResult(result) {
            console.log('📤 테스트 결과 전송:', result);
            
            try {
                if (window.certification_result && window.certification_result.postMessage) {
                    window.certification_result.postMessage(JSON.stringify(result));
                    return;
                }
            } catch (e) {
                console.log('📱 JavaScript Channel 실패, URL 시도:', e);
            }
            
            try {
                const params = new URLSearchParams(result);
                const url = 'flutter://certification_result?' + params.toString();
                console.log('🔗 URL 리다이렉트:', url);
                window.location.href = url;
            } catch (e) {
                console.error('❌ 결과 전송 실패:', e);
            }
        }
        
        function simulateSuccess() {
            const result = {
                success: 'true',
                imp_uid: 'test_imp_' + Date.now(),
                merchant_uid: '$merchantUid',
                error_msg: '',
                name: '테스트사용자',
                gender: 'male',
                birthday: '19900101',
                phone: '01012345678',
                carrier: 'SKT',
                foreigner: 'false'
            };
            sendResult(result);
        }
        
        function simulateFailure() {
            const result = {
                success: 'false',
                imp_uid: '',
                merchant_uid: '$merchantUid',
                error_msg: '사용자가 인증을 취소했습니다',
                name: '',
                gender: '',
                birthday: '',
                phone: '',
                carrier: '',
                foreigner: ''
            };
            sendResult(result);
        }
        
        function simulateMinor() {
            const result = {
                success: 'true',
                imp_uid: 'test_imp_minor_' + Date.now(),
                merchant_uid: '$merchantUid',
                error_msg: '',
                name: '미성년자',
                gender: 'female',
                birthday: '20070101', // 2007년생 = 18세 (2025년 기준)
                phone: '01087654321',
                carrier: 'KT',
                foreigner: 'false'
            };
            sendResult(result);
        }
    </script>
</body>
</html>
      ''';
    }
    
    // 실제 아임포트 모드 (V2 SDK 사용)
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>본인인증</title>
    <script src="https://cdn.portone.io/v2/browser-sdk.js"></script>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f8f9fa;
        }
        .container {
            text-align: center;
            padding: 50px 20px;
        }
        .spinner {
            width: 40px;
            height: 40px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #D2B48C;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .status {
            margin-top: 20px;
            font-size: 14px;
            color: #666;
        }
        .error {
            color: #e74c3c;
            background: #fee;
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
        }
        .debug {
            background: #f0f8ff;
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
            font-size: 12px;
            color: #666;
        }
        .button {
            background-color: #D2B48C;
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 8px;
            font-size: 16px;
            margin: 10px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <div class="container">
        <div style="font-size: 18px; margin-bottom: 20px;">본인인증 준비 중...</div>
        <div class="spinner"></div>
        <div id="status" class="status">아임포트 SDK 로딩 중...</div>
        
        <div id="debug-info" class="debug">
            <div>StoreId: $_storeId</div>
            <div>ChannelKey: ${_danalChannelKey.isNotEmpty ? _danalChannelKey : '⚠️ 미설정'}</div>
            <div>IdentityId: <span id="identity-id">생성 중...</span></div>
            <div>SDK: PortOne V2 (다날)</div>
            <div>상태: 초기화 중...</div>
        </div>
        
        <div id="error-section" style="display: none;">
            <div class="error" id="error-message"></div>
            <button class="button" onclick="retryInit()">다시 시도</button>
            <button class="button" onclick="showTestMode()">테스트 모드로 전환</button>
        </div>
    </div>
    
    <script>
        console.log('🔧 PortOne V2 본인인증 페이지 시작');
        console.log('🔑 StoreId:', '$_storeId');
        
        let initAttempts = 0;
        const maxAttempts = 15;
        
        function updateStatus(message) {
            console.log('📊 상태 업데이트:', message);
            const statusEl = document.getElementById('status');
            const debugEl = document.getElementById('debug-info');
            if (statusEl) {
                statusEl.textContent = message;
            }
            if (debugEl) {
                debugEl.children[2].textContent = '상태: ' + message;
            }
        }
        
        function showError(message) {
            console.error('❌ 에러 표시:', message);
            document.getElementById('error-message').textContent = message;
            document.getElementById('error-section').style.display = 'block';
        }
        
        function sendError(message) {
            console.error('❌ 에러 발생:', message);
            showError(message);
            
            const result = {
                success: 'false',
                error_msg: message,
                imp_uid: '',
                merchant_uid: '$merchantUid',
                name: '',
                gender: '',
                birthday: '',
                phone: '',
                carrier: '',
                foreigner: ''
            };
            sendResult(result);
        }
        
        function sendResult(result) {
            console.log('📤 결과 전송:', result);
            
            // JavaScript Channel 시도
            try {
                if (window.certification_result && window.certification_result.postMessage) {
                    window.certification_result.postMessage(JSON.stringify(result));
                    return;
                }
            } catch (e) {
                console.log('📱 JavaScript Channel 실패:', e);
            }
            
            // URL 리다이렉트 시도
            try {
                const params = new URLSearchParams(result);
                const url = 'flutter://certification_result?' + params.toString();
                console.log('🔗 URL 리다이렉트:', url);
                window.location.href = url;
            } catch (e) {
                console.error('❌ URL 리다이렉트 실패:', e);
            }
        }
        
        function retryInit() {
            console.log('🔄 재시도 시작');
            initAttempts = 0;
            document.getElementById('error-section').style.display = 'none';
            updateStatus('재시도 중...');
            checkPortOne();
        }
        
        function showTestMode() {
            console.log('🧪 테스트 모드로 전환');
            const result = {
                success: 'false',
                error_msg: '실제 인증 실패로 인한 테스트 모드 전환 요청',
                imp_uid: '',
                merchant_uid: '$merchantUid',
                name: '',
                gender: '',
                birthday: '',
                phone: '',
                carrier: '',
                foreigner: ''
            };
            sendResult(result);
        }
        
        // 에러 핸들링
        window.onerror = function(msg, url, line, col, error) {
            console.error('🚨 JavaScript 에러:', msg, 'at', url + ':' + line);
            sendError('JavaScript 오류: ' + msg);
        };
        
        // PortOne V2 SDK 확인 및 초기화
        function initPortOne() {
            if (typeof PortOne === 'undefined') {
                console.error('❌ PortOne 객체를 찾을 수 없습니다');
                sendError('PortOne V2 SDK 로딩에 실패했습니다');
                return;
            }
            
            updateStatus('PortOne V2 초기화 중...');
            
            try {
                console.log('✅ PortOne V2 초기화 완료');
                updateStatus('본인인증 시작 중...');
                
                setTimeout(startCertification, 1000);
            } catch (e) {
                console.error('❌ PortOne 초기화 실패:', e);
                sendError('PortOne 초기화 실패: ' + e.message);
            }
        }
        
        async function startCertification() {
            console.log('🔑 V2 본인인증 시작');
            updateStatus('본인인증 창 로딩 중...');
            
            try {
                // 공식 예제 형식으로 시도 (crypto.randomUUID() 지원 확인)
                let identityVerificationId;
                try {
                    identityVerificationId = `identity-verification-\${crypto.randomUUID()}`;
                } catch (e) {
                    // crypto.randomUUID() 지원 안 할 경우 대안 사용
                    identityVerificationId = 'identity-verification-' + Date.now() + '-' + Math.random().toString(36).substring(2);
                    console.log('crypto.randomUUID() 미지원, 대안 ID 생성:', identityVerificationId);
                }
                
                // 화면에 identityVerificationId 표시 (안전하게)
                const identityElement = document.getElementById('identity-id');
                if (identityElement) {
                    identityElement.textContent = identityVerificationId;
                } else {
                    console.log('⚠️ identity-id 요소를 찾을 수 없음, DOM이 아직 준비되지 않았을 수 있음');
                }
                
                // 기본 3개 파라미터만 사용 (사용자가 본인인증 창에서 직접 입력)
                const requestParams = {
                    storeId: '$_storeId',
                    identityVerificationId: identityVerificationId,
                    channelKey: '$_danalChannelKey'
                };
                
                console.log('📤 전송할 파라미터:', JSON.stringify(requestParams, null, 2));
                console.log('🔍 각 파라미터 상세:');
                console.log('  - storeId:', requestParams.storeId);
                console.log('  - identityVerificationId:', requestParams.identityVerificationId);
                console.log('  - channelKey:', requestParams.channelKey);
                
                const response = await PortOne.requestIdentityVerification(requestParams);
                
                console.log('📋 PortOne V2 응답:', JSON.stringify(response, null, 2));
                
                // 응답 처리
                if (response.code != null) {
                    // 에러 발생
                    sendError('인증 실패: ' + (response.message || '알 수 없는 오류'));
                } else {
                    // 성공 - 서버에서 상세 정보 조회 필요
                    const result = {
                        success: 'true',
                        imp_uid: identityVerificationId,
                        merchant_uid: '$merchantUid',
                        error_msg: '',
                        name: response.customer?.fullName || '',
                        gender: response.customer?.gender || '',
                        birthday: response.customer?.birthDate || '',
                        phone: response.customer?.phoneNumber || '',
                        carrier: '',
                        foreigner: 'false'
                    };
                    
                    sendResult(result);
                }
                
            } catch (e) {
                console.error('❌ V2 본인인증 시작 실패:', e);
                sendError('V2 본인인증 시작 실패: ' + e.message);
            }
        }
        
        function checkPortOne() {
            initAttempts++;
            updateStatus('V2 SDK 확인 중... (' + initAttempts + '/' + maxAttempts + ')');
            
            if (typeof PortOne !== 'undefined') {
                console.log('✅ PortOne V2 객체 발견');
                initPortOne();
            } else if (initAttempts < maxAttempts) {
                console.log('⏳ PortOne V2 SDK 대기 중... (' + initAttempts + '/' + maxAttempts + ')');
                setTimeout(checkPortOne, 1000);
            } else {
                console.error('❌ PortOne V2 SDK 로딩 타임아웃');
                sendError('PortOne V2 SDK 로딩 타임아웃 (15초)');
            }
        }
        
        // 페이지 로드 완료 후 초기화
        document.addEventListener('DOMContentLoaded', function() {
            console.log('📄 DOM 로드 완료');
            updateStatus('V2 SDK 확인 중...');
            
            // 네트워크 연결 상태 확인
            if (!navigator.onLine) {
                sendError('인터넷 연결을 확인해주세요');
                return;
            }
            
            checkPortOne();
        });
    </script>
</body>
</html>
    ''';
  }

  /// 성인인증 결과 검증
  static Future<CertificationResult> verifyCertification(Map<String, String> result) async {
    try {
      if (kDebugMode) {
        print('🔍 본인인증 결과 검증 시작');
        print('  Raw result: $result');
      }

      final certResult = CertificationResult.fromMap(result);
      
      if (kDebugMode) {
        print('  Parsed result: $certResult');
        print('  성인 여부: ${certResult.isAdult}');
        print('  이름: ${certResult.name}');
        print('  성별: ${certResult.normalizedGender}');
      }

      // 성공 여부 확인
      if (!certResult.success) {
        if (kDebugMode) {
          print('❌ 본인인증 실패: ${certResult.errorMessage}');
        }
        return certResult;
      }

      // 성인 여부 확인
      if (!certResult.isAdult) {
        if (kDebugMode) {
          print('❌ 성인인증 실패: 만 19세 미만');
        }
        return CertificationResult(
          success: false,
          isAdult: false,
          errorMessage: '만 19세 이상만 가입할 수 있습니다',
          name: certResult.name,
          gender: certResult.gender,
          birthday: certResult.birthday,
          phone: certResult.phone,
        );
      }

      if (kDebugMode) {
        print('✅ 성인인증 성공');
      }

      return certResult;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 본인인증 결과 처리 중 오류: $e');
      }
      
      return CertificationResult(
        success: false,
        isAdult: false,
        errorMessage: '본인인증 결과 처리 중 오류가 발생했습니다',
      );
    }
  }

  /// 아임포트 설정 검증
  static bool validateConfiguration() {
    final isValid = _storeId.isNotEmpty && // V2 Store ID 필수
                   _restApiKey.isNotEmpty && 
                   _restApiSecret.isNotEmpty &&
                   _danalChannelKey.isNotEmpty; // 다날 채널키도 필수
    
    if (!isValid && kDebugMode) {
      print('❌ 아임포트 설정이 완전하지 않습니다');
      print('  Store ID (V2): ${_storeId.isNotEmpty ? "설정됨" : "누락"}');
      print('  REST API Key: ${_restApiKey.isNotEmpty ? "설정됨" : "누락"}');
      print('  REST API Secret: ${_restApiSecret.isNotEmpty ? "설정됨" : "누락"}');
      print('  Danal Channel Key: ${_danalChannelKey.isNotEmpty ? "설정됨" : "⚠️ 누락 - Iamport 콘솔에서 다날 채널 설정 필요"}');
    }
    
    return isValid;
  }

  /// 로깅용 - 민감한 정보 제외하고 설정 상태 출력
  static void logConfigurationStatus() {
    if (kDebugMode) {
      print('🔧 아임포트 설정 상태:');
      print('  Store ID (V2): ${_storeId.isNotEmpty ? "${_storeId.substring(0, 8)}***" : "미설정"}');
      print('  REST API Key: ${_restApiKey.isNotEmpty ? "${_restApiKey.substring(0, 4)}***" : "미설정"}');
      print('  REST API Secret: ${_restApiSecret.isNotEmpty ? "${_restApiSecret.substring(0, 4)}***" : "미설정"}');
      print('  Danal Channel Key: ${_danalChannelKey.isNotEmpty ? "${_danalChannelKey.substring(0, 12)}***" : "⚠️ 미설정 - 다날 채널 필요"}');
    }
  }
}