import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/user_service.dart';
import 'nickname_input_screen.dart';
import 'privacy_consent_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleKakaoLogin() async {
    print('🎯 _handleKakaoLogin 함수 시작');
    setState(() {
      _isLoading = true;
    });

    try {
      print('🎯 KakaoAuthService.signInWithKakao() 호출 직전');
      final user = await KakaoAuthService.signInWithKakao();
      print('🎯 KakaoAuthService.signInWithKakao() 호출 완료, 결과: $user');
      
      if (user != null && mounted) {
        print('🔍 로그인 결과 확인:');
        print('  - 사용자 ID: ${user.id}');
        print('  - 사용자 이름: "${user.name}"');
        print('  - 카카오 ID: ${user.kakaoId}');
        print('  - 프로필 사진: ${user.profileImageUrl}');
        
        // 신규 사용자인지 기존 사용자인지 확인
        if (user.name == 'NEW_USER') {
          // 신규 사용자 - 개인정보 동의 화면으로 이동
          print('➡️ 신규 사용자 → 개인정보 동의 화면으로 이동');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PrivacyConsentScreen(
                userId: user.id,
                defaultName: user.name,
                profileImageUrl: user.profileImageUrl,
                email: user.email,
                kakaoId: user.kakaoId,
              ),
            ),
          );
        } else {
          // 기존 사용자 - 약간의 지연 후 홈 화면으로 이동 (Firestore 업데이트 완료 대기)
          print('➡️ 기존 사용자 → 홈 화면으로 이동 (Firestore 완료 대기 중...)');
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오 로그인 실패: $e'),
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

  void _handleSocialLogin(BuildContext context, String provider) {
    // TODO: 다른 소셜 로그인 구현
    print('🎯 _handleSocialLogin 호출됨: $provider');
    
    if (provider == '카카오') {
      print('🎯 카카오 로그인 분기 진입');
      _handleKakaoLogin();
    } else {
      print('🎯 다른 소셜 로그인: $provider');
      // 임시로 홈 화면으로 이동
      Navigator.pushReplacementNamed(context, '/home');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    // 앱 아이콘 (스플래시 화면과 동일)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '혼밥노노',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '혼여는 좋지만 맛집은 함께 🥹',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Section
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Social Login Buttons - 카카오만
                    _buildSocialButton(
                      onPressed: _isLoading ? null : () => _handleSocialLogin(context, '카카오'),
                      backgroundColor: const Color(0xFFFEE500),
                      textColor: const Color(0xFF3C1E1E),
                      icon: _isLoading ? null : 'K',
                      text: _isLoading ? '로그인 중...' : '카카오톡으로 시작하기',
                      isLoading: _isLoading,
                      isKakao: true,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Footer
                    const Text(
                      '가입 시 이용약관 및 개인정보처리방침에 동의합니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 사업자 정보
                    const Text(
                      '© 2025 구구랩. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF999999),
                        height: 1.4,
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

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color textColor,
    String? icon,
    required String text,
    bool isNaver = false,
    bool isKakao = false,
    bool isLoading = false,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDisabled ? 0 : 0,
          disabledBackgroundColor: backgroundColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else if (icon != null) ...[
              if (isNaver || isKakao)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isKakao ? const Color(0xFF3C1E1E) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      icon!,
                      style: TextStyle(
                        fontSize: isKakao ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: isKakao ? const Color(0xFFFEE500) : textColor,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  icon!,
                  style: const TextStyle(fontSize: 20),
                ),
            ],
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}