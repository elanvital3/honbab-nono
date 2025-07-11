import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/certification_service.dart';
import '../../models/certification_result.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_confirm_dialog.dart';
import 'nickname_input_screen.dart';
import 'webview_certification_screen.dart';

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
      builder: (context) => const CommonConfirmDialog(
        title: '설정 오류',
        content: '아임포트 본인인증 설정이 완전하지 않습니다.\n관리자에게 문의해주세요.',
        confirmText: '확인',
        icon: Icons.error_outline,
        iconColor: Colors.red,
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

      // WebView 기반 성인인증 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewCertificationScreen(
            name: widget.defaultName,
            onResult: _handleCertificationResult,
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

  void _handleCertificationResult(CertificationResult certResult) {
    try {
      if (kDebugMode) {
        print('📋 AdultVerification: 본인인증 결과 수신: $certResult');
        print('📋 AdultVerification: success=${certResult.success}, isAdult=${certResult.isAdult}');
        print('📋 AdultVerification: mounted=$mounted');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (certResult.success && certResult.isAdult) {
          if (kDebugMode) {
            print('✅ AdultVerification: 성공 조건 만족, 닉네임 입력 화면으로 이동');
          }
          // 성공 시 닉네임 입력 화면으로 이동
          _navigateToNicknameInput(certResult);
        } else {
          if (kDebugMode) {
            print('❌ AdultVerification: 성공 조건 불만족, 에러 다이얼로그 표시');
          }
          // 실패 시 에러 다이얼로그 표시
          _showErrorDialog(certResult.errorMessage ?? '본인인증에 실패했습니다.');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ AdultVerification: mounted=false, 위젯이 이미 제거됨');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdultVerification: 본인인증 결과 처리 중 오류: $e');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('본인인증 결과를 처리하는 중 오류가 발생했습니다.');
      }
    }
  }

  void _navigateToNicknameInput(CertificationResult certResult) {
    if (kDebugMode) {
      print('🚀 AdultVerification: _navigateToNicknameInput 시작');
      print('  - userId: ${widget.userId}');
      print('  - verifiedName: ${certResult.name}');
      print('  - verifiedGender: ${certResult.normalizedGender}');
      print('  - verifiedBirthYear: ${certResult.birthYear}');
      print('  - verifiedPhone: ${certResult.formattedPhone}');
    }
    
    // WebView 정리를 위한 약간의 딜레이 후 네비게이션
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) {
        if (kDebugMode) {
          print('⚠️ AdultVerification: 위젯이 이미 dispose됨, 네비게이션 취소');
        }
        return;
      }
      
      try {
        if (kDebugMode) {
          print('🚀 AdultVerification: Navigator.pushReplacement 시작 (딜레이 후)');
          print('  - context 상태: ${context.mounted}');
          print('  - Navigator 사용 가능: ${Navigator.canPop(context)}');
        }
        
        final result = Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (kDebugMode) {
                print('🏗️ AdultVerification: NicknameInputScreen 빌더 실행');
              }
              return NicknameInputScreen(
                userId: widget.userId,
                profileImageUrl: widget.profileImageUrl,
                email: widget.email,
                kakaoId: widget.kakaoId,
                // 본인인증에서 받은 정보를 미리 설정
                verifiedName: certResult.name,
                verifiedGender: certResult.normalizedGender,
                verifiedBirthYear: certResult.birthYear,
                verifiedPhone: certResult.formattedPhone,
              );
            },
          ),
        );
        
        if (kDebugMode) {
          print('✅ AdultVerification: Navigator.push 호출 완료');
          print('  - result type: ${result.runtimeType}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ AdultVerification: Navigator.push 실패: $e');
          print('  - Stack trace: ${StackTrace.current}');
        }
      }
    });
  }
  
  void _skipVerification() {
    if (kDebugMode) {
      print('⏭️ AdultVerification: 본인인증 건너뛰기');
    }
    
    // 빈값으로 닉네임 입력 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NicknameInputScreen(
          userId: widget.userId,
          profileImageUrl: widget.profileImageUrl,
          email: widget.email,
          kakaoId: widget.kakaoId,
          // 본인인증 정보는 빈값으로 전달
          verifiedName: null,
          verifiedGender: null,
          verifiedBirthYear: null,
          verifiedPhone: null,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => CommonConfirmDialog(
        title: '본인인증 실패',
        content: message,
        confirmText: '확인',
        icon: Icons.error_outline,
        iconColor: Colors.red[600],
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
                flex: 2,
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
                      style: AppTextStyles.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '안전한 매칭 서비스 이용을 위해\n본인인증을 진행해주세요',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppDesignTokens.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Information Section
              Expanded(
                flex: 1,
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
                                style: AppTextStyles.bodyLarge.copyWith(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Button Section
              Column(
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
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 나중에 하기 버튼
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isLoading ? null : _skipVerification,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppDesignTokens.outline.withOpacity(0.3),
                            ),
                          ),
                        ),
                        child: Text(
                          '나중에 하기',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 안내 문구
                    Text(
                      '모임 참여 시 본인인증이 필요합니다',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppDesignTokens.onSurfaceVariant.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
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
        color: AppDesignTokens.onSurface.withOpacity(0.8),
        height: 1.4,
      ),
    );
  }
}