import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../home/home_screen.dart';
import '../../models/user_badge.dart';
import '../../components/user_badge_chip.dart';
import '../../constants/app_design_tokens.dart';

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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthYearController = TextEditingController();
  bool _isLoading = false;
  bool _isNicknameValid = false;
  String? _nicknameError;
  String? _selectedGender;
  String? _phoneError;
  String? _birthYearError;
  int _selectedBirthYear = 1990; // 기본값
  final Set<String> _selectedBadgeIds = <String>{}; // 뱃지 선택
  static const int _maxBadges = 3; // 최대 선택 가능한 뱃지 수

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_validateNickname);
    _phoneController.addListener(_validatePhone);
    
    // 본인인증에서 받은 정보로 미리 설정
    if (widget.verifiedName != null) {
      _nicknameController.text = widget.verifiedName!;
    }
    if (widget.verifiedGender != null) {
      _selectedGender = widget.verifiedGender;
    }
    if (widget.verifiedBirthYear != null) {
      _selectedBirthYear = widget.verifiedBirthYear!;
    }
    if (widget.verifiedPhone != null) {
      _phoneController.text = widget.verifiedPhone!;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _birthYearController.dispose();
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

  void _validatePhone() {
    final phone = _phoneController.text.trim();
    final cleanPhone = phone.replaceAll('-', '').replaceAll(' ', '');
    setState(() {
      if (phone.isEmpty) {
        _phoneError = null;
      } else if (cleanPhone.length != 11 || !cleanPhone.startsWith('010')) {
        _phoneError = '올바른 휴대폰 번호를 입력해주세요 (010-0000-0000)';
      } else {
        _phoneError = null;
      }
    });
  }

  void _validateBirthYear() {
    final year = _birthYearController.text.trim();
    final currentYear = DateTime.now().year;
    setState(() {
      if (year.isEmpty) {
        _birthYearError = null;
      } else {
        final birthYear = int.tryParse(year);
        if (birthYear == null || birthYear < 1900 || birthYear > currentYear - 14) {
          _birthYearError = '유효한 출생연도를 입력해주세요 (만 14세 이상)';
        } else {
          _birthYearError = null;
        }
      }
    });
  }

  bool _isFormValid() {
    return _isNicknameValid &&
           _selectedGender != null &&
           _phoneController.text.trim().isNotEmpty &&
           _phoneError == null;
           // 출생년도는 기본값이 있어서 항상 유효
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
      // 전화번호는 이미 포맷된 상태로 저장
      final formattedPhone = _phoneController.text.trim();
      
      // 사용자 정보 업데이트
      final user = await UserService.createUserWithNickname(
        id: widget.userId,
        name: _nicknameController.text.trim(),
        email: widget.email,
        phoneNumber: formattedPhone,
        gender: _selectedGender!,
        birthYear: _selectedBirthYear,
        profileImageUrl: widget.profileImageUrl,
        kakaoId: widget.kakaoId,
        badges: _selectedBadgeIds.toList(), // 선택된 뱃지 포함
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
                      '혼밥노노에서 사용할\n기본 정보를 입력해주세요',
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
                    // 안내 텍스트
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: const Color(0xFFD2B48C), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                '개인정보 수집 안내',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD2B48C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem('성별', '안전한 동성/이성 매칭을 위해 필요합니다'),
                          const SizedBox(height: 8),
                          _buildInfoItem('출생연도', '적절한 연령대 매칭을 위해 필요합니다'),
                          const SizedBox(height: 8),
                          _buildInfoItem('전화번호', '긴급 연락 및 계정 보안을 위해 필요합니다'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
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
                    
                    const SizedBox(height: 16),
                    
                    // 성별 선택
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '성별 *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildGenderButton('남성', 'male'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildGenderButton('여성', 'female'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 출생연도 선택
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '출생연도 *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedBirthYear,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF666666)),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF333333),
                              ),
                              items: _generateBirthYearItems(),
                              onChanged: _isLoading ? null : (int? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedBirthYear = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 전화번호 입력
                    TextField(
                      controller: _phoneController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                        _PhoneNumberFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: '전화번호 *',
                        hintText: '010-0000-0000',
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
                        errorText: _phoneError,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF333333),
                      ),
                      maxLength: 13, // 010-0000-0000 형태
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 뱃지 선택 섹션
                    _buildBadgeSelection(),
                    
                    const SizedBox(height: 24),
                    
                    // 완료 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isFormValid() && !_isLoading) 
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
                                  color: (_isFormValid() && !_isLoading) 
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

  Widget _buildInfoItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderButton(String label, String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: _isLoading ? null : () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD2B48C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD2B48C) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _generateBirthYearItems() {
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 80; // 80세까지
    final endYear = currentYear - 14;   // 만 14세까지
    
    return List.generate(
      endYear - startYear + 1,
      (index) {
        final year = endYear - index; // 최신 연도부터 정렬
        return DropdownMenuItem<int>(
          value: year,
          child: Text('$year년'),
        );
      },
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
        const SizedBox(height: 8),
        Text(
          '나를 잘 나타내는 특성을 선택해주세요 (최대 $_maxBadges개)',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
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
        
        // 뱃지 선택 - 스크롤 없이 전체 표시
        ...UserBadge.allCategories.map((category) {
          final badges = UserBadge.getBadgesByCategory(category);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges.map((badge) {
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
        }).toList(),
      ],
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    if (text.length <= 3) {
      return newValue;
    } else if (text.length <= 7) {
      return TextEditingValue(
        text: '${text.substring(0, 3)}-${text.substring(3)}',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    } else {
      return TextEditingValue(
        text: '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7)}',
        selection: TextSelection.collapsed(offset: text.length + 2),
      );
    }
  }
}