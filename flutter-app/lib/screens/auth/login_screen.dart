import 'package:flutter/material.dart';
import '../../services/kakao_auth_service.dart';
import 'signup_complete_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleKakaoLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await KakaoAuthService.signInWithKakao();
      
      if (user != null && mounted) {
        print('🔍 로그인 결과 확인:');
        print('  - 사용자 ID: ${user.id}');
        print('  - 사용자 이름: "${user.name}"');
        print('  - 카카오 ID: ${user.kakaoId}');
        print('  - 프로필 사진: ${user.profileImageUrl}');
        
        // 신규 사용자인지 기존 사용자인지 확인
        if (user.name == 'NEW_USER') {
          // 신규 사용자 - 닉네임 입력 화면으로 이동
          print('➡️ 신규 사용자 → 닉네임 입력 화면으로 이동');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SignupCompleteScreen(
                userId: user.id,
                defaultName: null, // 신규 사용자이므로 기본값 없음
                profileImageUrl: user.profileImageUrl,
                email: user.email,
                kakaoId: user.kakaoId,
              ),
            ),
          );
        } else {
          // 기존 사용자 - 바로 홈 화면으로 이동
          print('➡️ 기존 사용자 → 홈 화면으로 이동');
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
    print('$provider 로그인 시도');
    
    if (provider == '카카오') {
      _handleKakaoLogin();
    } else {
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
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Section
              Column(
                children: [
                  const SizedBox(height: 100),
                  const Text(
                    '🍽️',
                    style: TextStyle(fontSize: 80),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '혼밥노노',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '혼자 가기 어려운 맛집을\n함께 경험해보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                ],
              ),

              // Social Login Buttons
              Column(
                children: [
                  // Kakao Login
                  _buildSocialButton(
                    onPressed: _isLoading ? null : () => _handleSocialLogin(context, '카카오'),
                    backgroundColor: const Color(0xFFFEE500),
                    textColor: const Color(0xFF3C1E1E),
                    icon: _isLoading ? null : '💬',
                    text: _isLoading ? '로그인 중...' : '카카오로 시작하기',
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  
                  // Google Login
                  _buildSocialButton(
                    onPressed: () => _handleSocialLogin(context, '구글'),
                    backgroundColor: const Color(0xFF4285F4),
                    textColor: Colors.white,
                    icon: '🌐',
                    text: '구글로 시작하기',
                  ),
                  const SizedBox(height: 12),
                  
                  // Naver Login
                  _buildSocialButton(
                    onPressed: () => _handleSocialLogin(context, '네이버'),
                    backgroundColor: const Color(0xFF03C75A),
                    textColor: Colors.white,
                    icon: 'N',
                    text: '네이버로 시작하기',
                    isNaver: true,
                  ),
                ],
              ),

              // Footer
              const Column(
                children: [
                  Text(
                    '가입 시 이용약관 및 개인정보처리방침에 동의합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
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
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
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
              if (isNaver)
                Text(
                  icon!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
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