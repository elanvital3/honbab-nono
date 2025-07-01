import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../home/home_screen.dart';

class NicknameInputScreen extends StatefulWidget {
  final String userId;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;

  const NicknameInputScreen({
    super.key,
    required this.userId,
    this.profileImageUrl,
    this.email,
    this.kakaoId,
  });

  @override
  State<NicknameInputScreen> createState() => _NicknameInputScreenState();
}

class _NicknameInputScreenState extends State<NicknameInputScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _isNicknameValid = false;
  String? _nicknameError;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_validateNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _validateNickname() {
    final nickname = _nicknameController.text.trim();
    setState(() {
      if (nickname.isEmpty) {
        _isNicknameValid = false;
        _nicknameError = null;
      } else if (nickname.length < 2) {
        _isNicknameValid = false;
        _nicknameError = '닉네임은 2글자 이상이어야 합니다';
      } else if (nickname.length > 10) {
        _isNicknameValid = false;
        _nicknameError = '닉네임은 10글자 이하여야 합니다';
      } else {
        _isNicknameValid = true;
        _nicknameError = null;
      }
    });
  }

  Future<void> _checkNicknameAvailability() async {
    final nickname = _nicknameController.text.trim();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final existingUser = await UserService.getUserByNickname(nickname);
      
      if (existingUser != null && mounted) {
        setState(() {
          _isNicknameValid = false;
          _nicknameError = '이미 사용중인 닉네임입니다';
          _isLoading = false;
        });
        return;
      }

      // 닉네임이 사용 가능하면 회원가입 완료
      await _completeSignup();
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _nicknameError = '닉네임 확인 중 오류가 발생했습니다';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeSignup() async {
    try {
      // 사용자 정보 업데이트
      final user = await UserService.createUserWithNickname(
        id: widget.userId,
        name: _nicknameController.text.trim(),
        email: widget.email,
        profileImageUrl: widget.profileImageUrl,
        kakaoId: widget.kakaoId,
      );

      if (user != null && mounted) {
        // FCM 토큰 저장 (백그라운드에서 실행)
        _saveFCMTokenInBackground(user.id);
        
        // 회원가입 완료 - 홈 화면으로 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nicknameError = '회원가입 중 오류가 발생했습니다';
          _isLoading = false;
        });
      }
    }
  }
  
  // FCM 토큰을 백그라운드에서 저장
  void _saveFCMTokenInBackground(String userId) {
    Future.microtask(() async {
      try {
        await NotificationService().initialize();
        await NotificationService().saveFCMTokenToFirestore(userId);
        if (kDebugMode) {
          print('✅ 회원가입 완료: FCM 토큰 저장 백그라운드 작업 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 회원가입 FCM 토큰 저장 실패: $e');
        }
      }
    });
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD2B48C),
            Color(0xFFC4A484),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Header Section
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 프로필 사진 또는 기본 아바타
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD2B48C),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
                            ? Image.network(
                                widget.profileImageUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar();
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF5F5F5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD2B48C)),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '환영합니다!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '혼밥노노에서 사용할\n닉네임을 입력해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ],
                    ),
                  ),

                  // Input Section
                  Expanded(
                    child: Column(
                  children: [
                    // 닉네임 입력 필드
                    TextField(
                      controller: _nicknameController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        hintText: '2-10글자로 입력해주세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD2B48C), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        errorText: _nicknameError,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF333333),
                      ),
                      maxLength: 10,
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 완료 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isNicknameValid && !_isLoading) 
                            ? _checkNicknameAvailability 
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD2B48C),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
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
                                '시작하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: (_isNicknameValid && !_isLoading) 
                                      ? Colors.white 
                                      : const Color(0xFF999999),
                                ),
                              ),
                      ),
                    ),
                  ],
                    ),
                  ),

                  // Footer
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}