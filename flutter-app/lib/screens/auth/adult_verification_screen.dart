import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iamport_flutter/iamport_certification.dart';
import '../../services/certification_service.dart';
import '../../models/certification_result.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import 'nickname_input_screen.dart';

class AdultVerificationScreen extends StatefulWidget {
  final String userId;
  final String? defaultName;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;

  const AdultVerificationScreen({
    super.key,
    required this.userId,
    this.defaultName,
    this.profileImageUrl,
    this.email,
    this.kakaoId,
  });

  @override
  State<AdultVerificationScreen> createState() => _AdultVerificationScreenState();
}

class _AdultVerificationScreenState extends State<AdultVerificationScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // 아임포트 설정 확인
    if (!CertificationService.validateConfiguration()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConfigurationError();
      });
    } else {
      CertificationService.logConfigurationStatus();
    }
  }

  void _showConfigurationError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('설정 오류'),
        content: const Text('아임포트 본인인증 설정이 완전하지 않습니다.\n관리자에게 문의해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _startAdultVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('🔑 성인인증 시작');
      }

      // 성인인증 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IamportCertification(
            appBar: AppBar(
              title: const Text('본인인증'),
              backgroundColor: AppDesignTokens.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            initialChild: Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 앱 아이콘
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppDesignTokens.primary,
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '본인인증 진행 중...',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '잠시만 기다려주세요',
                      style: AppTextStyles.body.copyWith(
                        color: AppDesignTokens.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppDesignTokens.primary),
                    ),
                  ],
                ),
              ),
            ),
            userCode: dotenv.env['IAMPORT_USER_CODE'] ?? '',
            data: CertificationService.createAdultVerificationData(
              name: widget.defaultName,
            ),
            callback: _handleCertificationResult,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 성인인증 시작 중 오류: $e');
      }
      
      if (mounted) {
        _showErrorDialog('본인인증을 시작할 수 없습니다.\n다시 시도해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCertificationResult(Map<String, String> result) async {
    try {
      if (kDebugMode) {
        print('📋 본인인증 결과 수신: $result');
      }

      // 결과 검증
      final certResult = await CertificationService.verifyCertification(result);
      
      if (mounted) {
        // 성인인증 화면 닫기
        Navigator.of(context).pop();
        
        if (certResult.success && certResult.isAdult) {
          // 성공 시 닉네임 입력 화면으로 이동
          _navigateToNicknameInput(certResult);
        } else {
          // 실패 시 에러 다이얼로그 표시
          _showErrorDialog(certResult.errorMessage ?? '본인인증에 실패했습니다.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 본인인증 결과 처리 중 오류: $e');
      }
      
      if (mounted) {
        Navigator.of(context).pop(); // 인증 화면 닫기
        _showErrorDialog('본인인증 결과를 처리하는 중 오류가 발생했습니다.');
      }
    }
  }

  void _navigateToNicknameInput(CertificationResult certResult) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NicknameInputScreen(
          userId: widget.userId,
          profileImageUrl: widget.profileImageUrl,
          email: widget.email,
          kakaoId: widget.kakaoId,
          // 본인인증에서 받은 정보를 미리 설정
          verifiedName: certResult.name,
          verifiedGender: certResult.normalizedGender,
          verifiedBirthYear: certResult.birthYear,
          verifiedPhone: certResult.formattedPhone,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[600],
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('본인인증 실패'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Header Section
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 인증 아이콘
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppDesignTokens.primary,
                            AppDesignTokens.primary.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignTokens.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '성인인증이 필요합니다',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '안전한 매칭 서비스 이용을 위해\n본인인증을 진행해주세요',
                      style: AppTextStyles.body.copyWith(
                        color: AppDesignTokens.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Information Section
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppDesignTokens.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppDesignTokens.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '본인인증 안내',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoItem('• 만 19세 이상 성인만 가입 가능'),
                          const SizedBox(height: 8),
                          _buildInfoItem('• 실명 인증으로 안전한 매칭 보장'),
                          const SizedBox(height: 8),
                          _buildInfoItem('• 개인정보는 안전하게 보호됩니다'),
                          const SizedBox(height: 8),
                          _buildInfoItem('• 카카오 개발자 정책 준수'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Button Section
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 본인인증 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _startAdultVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignTokens.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                '본인인증 시작하기',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppDesignTokens.onSurface.withOpacity(0.8),
        height: 1.4,
      ),
    );
  }
}