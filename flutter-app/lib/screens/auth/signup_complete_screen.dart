import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../profile/badge_selection_screen.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../components/common/common_button.dart';

class SignupCompleteScreen extends StatefulWidget {
  final String userId;
  final String? defaultName;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;

  const SignupCompleteScreen({
    super.key,
    required this.userId,
    this.defaultName,
    this.profileImageUrl,
    this.email,
    this.kakaoId,
  });

  @override
  State<SignupCompleteScreen> createState() => _SignupCompleteScreenState();
}

class _SignupCompleteScreenState extends State<SignupCompleteScreen> {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isCheckingNickname = false;
  bool _isNicknameAvailable = false;
  String? _nicknameError;

  @override
  void initState() {
    super.initState();
    // 카카오에서 가져온 이름을 기본값으로 설정
    if (widget.defaultName != null && widget.defaultName!.isNotEmpty) {
      _nicknameController.text = widget.defaultName!;
      _checkNicknameAvailability(widget.defaultName!);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _checkNicknameAvailability(String nickname) async {
    if (nickname.isEmpty) {
      setState(() {
        _isNicknameAvailable = false;
        _nicknameError = null;
      });
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _nicknameError = null;
    });

    try {
      // 닉네임 중복 체크
      final existingUser = await UserService.getUserByNickname(nickname);
      
      setState(() {
        _isNicknameAvailable = existingUser == null;
        _nicknameError = existingUser != null ? '이미 사용중인 닉네임입니다' : null;
      });
    } catch (e) {
      setState(() {
        _isNicknameAvailable = false;
        _nicknameError = '닉네임 확인 중 오류가 발생했습니다';
      });
    } finally {
      setState(() {
        _isCheckingNickname = false;
      });
    }
  }

  Future<void> _completeSignup() async {
    if (!_formKey.currentState!.validate() || !_isNicknameAvailable) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 정보를 Firestore에 저장
      final user = await UserService.createUserWithNickname(
        id: widget.userId,
        name: _nicknameController.text.trim(),
        email: widget.email,
        profileImageUrl: widget.profileImageUrl,
        kakaoId: widget.kakaoId,
      );

      if (user != null && mounted) {
        if (kDebugMode) {
          print('✅ 회원가입 완료: ${user.name}');
        }

        // 뱃지 선택 화면으로 이동 (회원가입 모드)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const BadgeSelectionScreen(isOnboarding: true),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 회원가입 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원가입 중 오류가 발생했습니다: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // 환영 메시지
                Text(
                  '환영합니다! 🎉',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontSize: 28,
                    color: AppDesignTokens.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '혼밥노노에서 사용할 닉네임을 설정해주세요',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppDesignTokens.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // 프로필 사진 미리보기
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: widget.profileImageUrl != null
                          ? Image.network(
                              widget.profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar();
                              },
                            )
                          : _buildDefaultAvatar(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 닉네임 입력
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '닉네임',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력해주세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD2B48C)),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        suffixIcon: _isCheckingNickname
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD2B48C),
                                  ),
                                ),
                              )
                            : _isNicknameAvailable && _nicknameController.text.isNotEmpty
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                        errorText: _nicknameError,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '닉네임을 입력해주세요';
                        }
                        if (value.trim().length < 2) {
                          return '닉네임은 2글자 이상이어야 합니다';
                        }
                        if (value.trim().length > 12) {
                          return '닉네임은 12글자 이하이어야 합니다';
                        }
                        if (!_isNicknameAvailable) {
                          return _nicknameError ?? '사용할 수 없는 닉네임입니다';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.trim().isNotEmpty) {
                          // 500ms 후에 중복 체크 (타이핑 중에는 너무 자주 체크하지 않도록)
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_nicknameController.text.trim() == value.trim()) {
                              _checkNicknameAvailability(value.trim());
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),

                // 적절한 여백 추가 (키보드 고려)
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 60),

                // 완료 버튼
                CommonButton(
                  text: '완료',
                  onPressed: _isLoading || _isCheckingNickname || !_isNicknameAvailable 
                      ? null 
                      : _completeSignup,
                  isLoading: _isLoading,
                  fullWidth: true,
                  size: ButtonSize.large,
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5F5F5),
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Color(0xFFBBBBBB),
      ),
    );
  }
}