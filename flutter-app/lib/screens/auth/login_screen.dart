import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/user_service.dart';
import 'nickname_input_screen.dart';
import 'privacy_consent_screen.dart';
import '../../main.dart';

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
      final success = await KakaoAuthService.signInWithKakao();
      print('🎯 KakaoAuthService.signInWithKakao() 호출 완료, 결과: $success');
      
      if (success) {
        // 카카오 로그인 성공
        print('✅ 카카오 로그인 성공');
        
        // 카카오 정보 확인
        final kakaoInfo = KakaoAuthService.getTempKakaoUserInfo();
        print('🔍 LoginScreen: 카카오 정보 확인 중...');
        print('  - kakaoInfo: $kakaoInfo');
        print('  - kakaoInfo == null: ${kakaoInfo == null}');
        print('  - mounted: $mounted');
        
        if (kakaoInfo != null && mounted) {
          // 신규 사용자 - 회원가입 프로세스 시작
          print('🆕 LoginScreen: 신규 사용자 감지 → 회원가입 프로세스 시작');
          print('✅ 카카오 정보 확인:');
          print('  - 이메일: ${kakaoInfo['email']}');
          print('  - 카카오ID: ${kakaoInfo['kakaoId']}');
          print('  - 닉네임: ${kakaoInfo['name']}');
          
          // 즉시 네비게이션 실행
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('🚀 LoginScreen: PrivacyConsentScreen 네비게이션 시작');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PrivacyConsentScreen(
                    userId: null, // Firebase Auth는 회원가입 완료 시 생성
                    email: kakaoInfo['email'],
                    kakaoId: kakaoInfo['kakaoId'],
                    defaultName: kakaoInfo['name'],
                    profileImageUrl: kakaoInfo['profileImageUrl'],
                  ),
                ),
              );
            } else {
              print('❌ LoginScreen: mounted=false, 네비게이션 건너뜀');
            }
          });
        } else {
          // 기존 사용자 또는 카카오 정보 없음
          if (kakaoInfo == null) {
            print('❌ LoginScreen: 카카오 정보가 null → 기존 사용자 또는 오류');
          } else {
            print('❌ LoginScreen: mounted=false → 네비게이션 불가');
          }
          print('✅ 기존 사용자 로그인 성공 → AuthWrapper가 홈 화면으로 라우팅');
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