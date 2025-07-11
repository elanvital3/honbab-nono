import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/certification_service.dart';
import '../../services/user_service.dart';
import '../../models/certification_result.dart';
import '../../components/common/common_confirm_dialog.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../home/home_screen.dart';
import 'webview_certification_screen.dart';

class ExistingUserAdultVerificationScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ExistingUserAdultVerificationScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ExistingUserAdultVerificationScreen> createState() => _ExistingUserAdultVerificationScreenState();
}

class _ExistingUserAdultVerificationScreenState extends State<ExistingUserAdultVerificationScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppDesignTokens.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '성인인증',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppDesignTokens.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // 제목
              Text(
                '안전한 서비스 이용을 위해\n성인인증이 필요합니다',
                style: AppTextStyles.headlineMedium.copyWith(
                  height: 1.3,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 설명
              Text(
                '${widget.userName}님, 안녕하세요!\n\n안전한 매칭 서비스 이용을 위해 성인인증이 필요합니다. 본인인증을 통해 만 19세 이상임을 확인해주세요.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 안내 카드
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppDesignTokens.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: AppDesignTokens.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '본인인증 안내',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppDesignTokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem('• 휴대폰 본인인증을 통한 성인 확인'),
                    const SizedBox(height: 4),
                    _buildInfoItem('• 개인정보는 암호화되어 안전하게 보호'),
                    const SizedBox(height: 4),
                    _buildInfoItem('• 인증 완료 후 모든 기능 이용 가능'),
                  ],
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              
              // 버튼 영역
              Column(
                children: [
                  // 성인인증 시작 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _startAdultVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppDesignTokens.outline.withOpacity(0.3),
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
                              '성인인증 시작하기',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 나중에 하기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '나중에 하기',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppDesignTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
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
      style: AppTextStyles.bodySmall.copyWith(
        color: AppDesignTokens.primary,
        height: 1.4,
      ),
    );
  }

  Future<void> _startAdultVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 아임포트 설정 검증
      if (!CertificationService.validateConfiguration()) {
        throw Exception('성인인증 서비스가 설정되지 않았습니다');
      }

      if (kDebugMode) {
        print('🔄 기존 사용자 성인인증 시작: ${widget.userId}');
        CertificationService.logConfigurationStatus();
      }

      // WebView 기반 성인인증 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewCertificationScreen(
            name: widget.userName,
            onResult: _handleCertificationResult,
          ),
        ),
      );

    } catch (e) {
      if (kDebugMode) {
        print('❌ 성인인증 시작 실패: $e');
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '성인인증 중 오류가 발생했습니다: ${e.toString()}';
      });
    }
  }

  void _handleCertificationResult(CertificationResult certResult) {
    try {
      if (kDebugMode) {
        print('📋 기존 사용자 본인인증 결과 수신: $certResult');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (certResult.success && certResult.isAdult) {
          // 성공 시 사용자 정보 업데이트
          _updateUserVerificationInfo(certResult);
        } else {
          // 실패 시 에러 메시지 표시
          setState(() {
            _errorMessage = certResult.errorMessage ?? '성인인증에 실패했습니다';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 본인인증 결과 처리 중 오류: $e');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '본인인증 결과를 처리하는 중 오류가 발생했습니다';
        });
      }
    }
  }

  Future<void> _updateUserVerificationInfo(CertificationResult certResult) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 기존 사용자 성인인증 정보 업데이트
      await UserService.updateUserWithAdultVerification(
        userId: widget.userId,
        verifiedName: certResult.name,
        verifiedGender: certResult.normalizedGender,
        verifiedBirthYear: certResult.birthYear,
        verifiedPhone: certResult.formattedPhone,
      );

      if (kDebugMode) {
        print('✅ 기존 사용자 성인인증 완료: ${widget.userId}');
      }

      // 성공 메시지와 함께 홈으로 이동
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('성인인증이 완료되었습니다! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 정보 업데이트 실패: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '사용자 정보 업데이트 중 오류가 발생했습니다';
        });
      }
    }
  }
}