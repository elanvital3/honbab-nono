import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/user_service.dart';
import '../../services/privacy_consent_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../constants/privacy_policy_content.dart';
import 'nickname_input_screen.dart';
import 'privacy_policy_screen.dart';
import '../home/home_screen.dart';

class PrivacyConsentScreen extends StatefulWidget {
  final String userId;
  final String? defaultName;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;
  final bool isUpdate;

  const PrivacyConsentScreen({
    super.key,
    required this.userId,
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
  bool _optionalConsent = true; // 선택 동의 - 기본 체크
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            // 메인 컨텐츠 (스크롤 가능)
            Expanded(
              child: SingleChildScrollView(
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
                    
                    const SizedBox(height: 40),
                    
                    // 추가 정보 (간단하게)
                    _buildInfoSection(),
                    
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
            
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
        Text(
          '선택 약관',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppDesignTokens.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        
        // 필수 동의 옵션
        _buildConsentOption(
          title: '개인정보 수집 · 이용 동의 (필수)',
          isSelected: _essentialConsent,
          onTap: () {
            setState(() {
              _essentialConsent = !_essentialConsent;
            });
          },
          onDetailTap: () => _showConsentDetail('essential'),
        ),
        
        const SizedBox(height: 12),
        
        // 선택 동의 옵션  
        _buildConsentOption(
          title: '서비스 품질 향상을 위한 개인정보 수집 · 이용 동의 (선택)',
          isSelected: _optionalConsent,
          onTap: () {
            setState(() {
              _optionalConsent = !_optionalConsent;
            });
          },
          onDetailTap: () => _showConsentDetail('marketing'),
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
            
            // 화살표 아이콘
            GestureDetector(
              onTap: onDetailTap,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_right,
                  color: AppDesignTokens.outline,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppDesignTokens.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '개인정보 처리 안내',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppDesignTokens.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 수집하는 개인정보: 이름, 이메일, 프로필 사진 등\n'
            '• 개인정보는 서비스 제공 목적으로만 사용됩니다\n'
            '• 개인정보 보관기간: 회원 탈퇴 시까지\n'
            '• 언제든지 동의를 철회하실 수 있습니다',
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.5,
              color: AppDesignTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showFullPrivacyPolicy,
            child: Text(
              '개인정보 처리방침 전문 보기',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
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
      final consentData = <String, bool>{
        'essential': _essentialConsent,
        'marketing': _optionalConsent, // 사용자 선택에 따라
        'location': _optionalConsent, // 선택 동의와 함께 처리
      };

      await PrivacyConsentService.saveConsent(
        userId: widget.userId,
        consentData: consentData,
      );

      if (kDebugMode) {
        print('✅ 개인정보 동의 저장 완료');
      }

      if (mounted) {
        if (widget.isUpdate) {
          // 설정 업데이트인 경우 홈으로
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // 신규 가입인 경우 닉네임 입력으로
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => NicknameInputScreen(
                userId: widget.userId,
                profileImageUrl: widget.profileImageUrl,
                email: widget.email,
                kakaoId: widget.kakaoId,
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
    Navigator.of(context).pop();
  }

  void _showConsentDetail(String consentType) {
    final content = PrivacyPolicyContent.consentItems[consentType] ?? '';
    final title = consentType == 'essential' ? '필수 동의 항목' : '선택 동의 항목';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 핸들 바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignTokens.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 헤더
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppDesignTokens.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // 내용
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    content,
                    style: AppTextStyles.bodyLarge.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(),
      ),
    );
  }
}