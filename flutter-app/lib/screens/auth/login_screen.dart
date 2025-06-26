import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _handleSocialLogin(BuildContext context, String provider) {
    // TODO: 소셜 로그인 구현
    print('$provider 로그인 시도');
    
    // 임시로 홈 화면으로 이동
    Navigator.pushReplacementNamed(context, '/home');
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
                    onPressed: () => _handleSocialLogin(context, '카카오'),
                    backgroundColor: const Color(0xFFFEE500),
                    textColor: const Color(0xFF3C1E1E),
                    icon: '💬',
                    text: '카카오로 시작하기',
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
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    required String icon,
    required String text,
    bool isNaver = false,
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
            if (isNaver)
              Text(
                icon,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              )
            else
              Text(
                icon,
                style: const TextStyle(fontSize: 20),
              ),
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