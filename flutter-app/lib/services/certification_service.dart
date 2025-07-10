import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iamport_flutter/iamport_certification.dart';
import 'package:iamport_flutter/model/certification_data.dart';
import '../models/certification_result.dart';

class CertificationService {
  static String get _userCode => dotenv.env['IAMPORT_USER_CODE'] ?? '';
  static String get _restApiKey => dotenv.env['IAMPORT_REST_API_KEY'] ?? '';
  static String get _restApiSecret => dotenv.env['IAMPORT_REST_API_SECRET'] ?? '';

  /// 성인인증 데이터 생성
  static CertificationData createAdultVerificationData({
    String? name,
    String? phone,
  }) {
    final merchantUid = 'cert_${DateTime.now().millisecondsSinceEpoch}';
    
    return CertificationData(
      pg: 'danal',  // 다날 본인인증 사용
      merchantUid: merchantUid,
      company: '혼밥노노',  // 회사명
      carrier: null,  // 통신사는 사용자가 선택
      name: name,
      phone: phone,
      minAge: 19,  // 만 19세 이상 성인인증
    );
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
    final isValid = _userCode.isNotEmpty && 
                   _restApiKey.isNotEmpty && 
                   _restApiSecret.isNotEmpty;
    
    if (!isValid && kDebugMode) {
      print('❌ 아임포트 설정이 완전하지 않습니다');
      print('  User Code: ${_userCode.isNotEmpty ? "설정됨" : "누락"}');
      print('  REST API Key: ${_restApiKey.isNotEmpty ? "설정됨" : "누락"}');
      print('  REST API Secret: ${_restApiSecret.isNotEmpty ? "설정됨" : "누락"}');
    }
    
    return isValid;
  }

  /// 로깅용 - 민감한 정보 제외하고 설정 상태 출력
  static void logConfigurationStatus() {
    if (kDebugMode) {
      print('🔧 아임포트 설정 상태:');
      print('  User Code: ${_userCode.isNotEmpty ? _userCode : "미설정"}');
      print('  REST API Key: ${_restApiKey.isNotEmpty ? "${_restApiKey.substring(0, 4)}***" : "미설정"}');
      print('  REST API Secret: ${_restApiSecret.isNotEmpty ? "${_restApiSecret.substring(0, 4)}***" : "미설정"}');
    }
  }
}