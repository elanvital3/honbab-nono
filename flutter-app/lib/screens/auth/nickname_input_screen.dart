import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../../services/deletion_history_service.dart';
import '../home/home_screen.dart';
import '../../models/user_badge.dart';
import '../../components/user_badge_chip.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_button.dart';

class NicknameInputScreen extends StatefulWidget {
  final String userId;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;
  // 본인인증에서 받은 정보들
  final String? verifiedName;
  final String? verifiedGender;
  final int? verifiedBirthYear;
  final String? verifiedPhone;

  const NicknameInputScreen({
    super.key,
    required this.userId,
    this.profileImageUrl,
    this.email,
    this.kakaoId,
    this.verifiedName,
    this.verifiedGender,
    this.verifiedBirthYear,
    this.verifiedPhone,
  });

  @override
  State<NicknameInputScreen> createState() => _NicknameInputScreenState();
}

class _NicknameInputScreenState extends State<NicknameInputScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _isNicknameValid = false;
  String? _nicknameError;
  final Set<String> _selectedBadgeIds = <String>{}; // 뱃지 선택
  static const int _maxBadges = 3; // 최대 선택 가능한 뱃지 수

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
      print('🆔 NicknameInputScreen: initState 시작');
      print('  - userId: ${widget.userId}');
      print('  - verifiedName: ${widget.verifiedName}');
    }
    
    _nicknameController.addListener(_validateNickname);
    
    // 본인인증에서 받은 정보로 미리 설정
    if (widget.verifiedName != null) {
      _nicknameController.text = widget.verifiedName!;
      if (kDebugMode) {
        print('✅ NicknameInputScreen: 닉네임 미리 설정 - ${widget.verifiedName}');
      }
    }
    
    if (kDebugMode) {
      print('✅ NicknameInputScreen: initState 완료');
    }
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


  bool _isFormValid() {
    // 닉네임만 체크 (성인인증에서 나머지 정보를 받을 예정)
    return _isNicknameValid;
  }

  Future<void> _checkNicknameAvailability() async {
    final nickname = _nicknameController.text.trim();
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 재가입 제한 확인 (중요!)
      final reactivationStatus = await DeletionHistoryService.checkReactivationStatus(
        kakaoId: widget.kakaoId,
        email: widget.email,
      );
      
      if (!reactivationStatus.allowed) {
        if (mounted) {
          setState(() {
            _nicknameError = reactivationStatus.displayMessage;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. 닉네임 중복 확인
      final existingUser = await UserService.getUserByNickname(nickname);
      
      if (existingUser != null && mounted) {
        setState(() {
          _isNicknameValid = false;
          _nicknameError = '이미 사용중인 닉네임입니다';
          _isLoading = false;
        });
        return;
      }

      // 3. 닉네임이 사용 가능하면 회원가입 완료
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
      // 본인인증 여부 확인
      final isVerified = widget.verifiedName != null;
      
      if (kDebugMode) {
        print('🔄 NicknameInput: 회원가입 정보');
        print('  - 본인인증 여부: $isVerified');
        print('  - 닉네임: ${_nicknameController.text.trim()}');
        print('  - 성별: ${widget.verifiedGender}');
        print('  - 출생연도: ${widget.verifiedBirthYear}');
        print('  - 전화번호: ${widget.verifiedPhone}');
      }
      
      // 사용자 정보 업데이트 (성인인증 정보만 저장, 없으면 null)
      final user = await UserService.createUserWithNickname(
        id: widget.userId,
        name: _nicknameController.text.trim(),
        email: widget.email,
        phoneNumber: widget.verifiedPhone,
        gender: widget.verifiedGender,
        birthYear: widget.verifiedBirthYear,
        profileImageUrl: widget.profileImageUrl,
        kakaoId: widget.kakaoId,
        badges: _selectedBadgeIds.toList(), // 선택된 뱃지 포함
        isAdultVerified: isVerified, // 본인인증을 거쳤으면 true
        adultVerifiedAt: isVerified ? DateTime.now() : null,
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

  void _toggleBadge(String badgeId) {
    setState(() {
      if (_selectedBadgeIds.contains(badgeId)) {
        _selectedBadgeIds.remove(badgeId);
      } else {
        if (_selectedBadgeIds.length < _maxBadges) {
          _selectedBadgeIds.add(badgeId);
        } else {
          // 최대 개수 초과 시 알림
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('최대 $_maxBadges개까지만 선택할 수 있습니다'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
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
    if (kDebugMode) {
      print('🏗️ NicknameInputScreen: build 메서드 실행');
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                    Text(
                      '환영합니다!',
                      style: AppTextStyles.displayLarge.copyWith(
                        fontSize: 28,
                        color: AppDesignTokens.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '혼밥노노에서 사용할\n기본 정보를 입력해주세요',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppDesignTokens.onSurfaceVariant,
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
                        labelText: '닉네임 *',
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
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 뱃지 선택 섹션
                    _buildBadgeSelection(),
                    
                    const SizedBox(height: 24),
                    
                    // 완료 버튼
                    CommonButton(
                      text: '시작하기',
                      onPressed: (_isFormValid() && !_isLoading) 
                          ? _checkNicknameAvailability 
                          : null,
                      isLoading: _isLoading,
                      fullWidth: true,
                      size: ButtonSize.large,
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


  Widget _buildBadgeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '나의 특성 (선택)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedBadgeIds.length}/$_maxBadges',
              style: TextStyle(
                fontSize: 14,
                color: AppDesignTokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 선택된 뱃지 표시
        if (_selectedBadgeIds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedBadgeIds.map((badgeId) {
              return UserBadgeChip(badgeId: badgeId, compact: true);
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // 뱃지 선택 - 카테고리 구분 없이 전체 나열
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: UserBadge.allBadges.map((badge) {
            final isSelected = _selectedBadgeIds.contains(badge.id);
            return GestureDetector(
              onTap: () => _toggleBadge(badge.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppDesignTokens.primary.withOpacity(0.1)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppDesignTokens.primary
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badge.emoji,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? AppDesignTokens.primary
                            : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[ 
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle,
                        color: AppDesignTokens.primary,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}