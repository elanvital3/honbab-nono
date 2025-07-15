import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/user_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../constants/privacy_policy_content.dart';
import 'adult_verification_screen.dart';
import 'privacy_policy_screen.dart';
import 'login_screen.dart';
import 'nickname_input_screen.dart';
import '../home/home_screen.dart';

class PrivacyConsentScreen extends StatefulWidget {
  final String? userId; // nullable로 변경 (회원가입 완료 시 생성)
  final String? defaultName;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;
  final bool isUpdate;

  const PrivacyConsentScreen({
    super.key,
    this.userId, // required 제거
    this.defaultName,
    this.profileImageUrl,
    this.email,
    this.kakaoId,
    this.isUpdate = false,
  });

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _isLoading = false;
  bool _essentialConsent = true; // 필수 동의 - 기본 체크
  
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🏗️ PrivacyConsentScreen 초기화됨');
      print('  - userId: ${widget.userId}');
      print('  - defaultName: ${widget.defaultName}');
      print('  - email: ${widget.email}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('🎨 PrivacyConsentScreen build() 호출됨');
    }
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 고정 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  
                  // 제목
                  Text(
                    '혼밥노노 사용하기 위해\n동의해 주세요.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineLarge.copyWith(
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 동의 옵션들
                  _buildConsentOptions(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // 개인정보 처리방침 전문 (스크롤 가능)
            Expanded(
              child: _buildPolicyContent(),
            ),
            
            const SizedBox(height: 24),
            
            // 하단 버튼 영역
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        // 필수 동의 옵션
        _buildConsentOption(
          title: '개인정보 수집 · 이용 동의 (필수)',
          isSelected: _essentialConsent,
          onTap: () {
            setState(() {
              _essentialConsent = !_essentialConsent;
            });
          },
          onDetailTap: () {}, // 더 이상 필요 없음 (전문이 이미 화면에 있음)
        ),
      ],
    );
  }

  Widget _buildConsentOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDetailTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesignTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppDesignTokens.primary 
                : AppDesignTokens.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 체크박스
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected 
                      ? AppDesignTokens.primary 
                      : AppDesignTokens.outline,
                  width: 2,
                ),
                color: isSelected 
                    ? AppDesignTokens.primary 
                    : AppDesignTokens.surface,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            // 제목 텍스트
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isSelected 
                      ? AppDesignTokens.onSurface 
                      : AppDesignTokens.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            
            // 화살표 아이콘 제거 (전문이 이미 화면에 표시됨)
          ],
        ),
      ),
    );
  }


  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        border: Border(
          top: BorderSide(
            color: AppDesignTokens.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 동의하고 시작하기 통합 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _essentialConsent && !_isLoading 
                  ? _handleAgree 
                  : null,
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
                      '동의하고 시작하기',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 취소 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _isLoading ? null : _handleCancel,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '취소',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppDesignTokens.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAgree() async {
    if (!_essentialConsent) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 동의 정보 저장
      // 개인정보 동의는 간소화 - 사용자 데이터에 포함
      if (kDebugMode) {
        print('✅ 개인정보 동의 처리 완료 (간소화)');
      }

      if (mounted) {
        if (widget.isUpdate) {
          // 설정 업데이트인 경우 홈으로
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // 신규 가입인 경우 성인인증 건너뛰고 바로 닉네임 입력으로
          // TODO: 성인인증 심사 완료 후 다시 활성화
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NicknameInputScreen(
                userId: widget.userId,
                profileImageUrl: widget.profileImageUrl,
                email: widget.email,
                kakaoId: widget.kakaoId,
                // 성인인증 정보는 임시로 null (심사 완료 시 복원)
                verifiedName: null,
                verifiedGender: null,
                verifiedBirthYear: null,
                verifiedPhone: null,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 개인정보 동의 저장 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동의 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleCancel() {
    // 로그인 화면으로 돌아가기 (모든 인증 스택을 지우고)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }


  Widget _buildPolicyContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24), // 버튼과 동일한 마진
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppDesignTokens.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          PrivacyPolicyContent.fullContent,
          style: AppTextStyles.bodySmall.copyWith(
            height: 1.4,
            color: AppDesignTokens.onSurfaceVariant,
            fontSize: 11, // 작은 글씨로 설정
          ),
        ),
      ),
    );
  }
}