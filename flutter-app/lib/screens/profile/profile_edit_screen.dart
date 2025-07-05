import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';
import '../../models/user_badge.dart';
import 'badge_selection_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  final app_user.User user;

  const ProfileEditScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  // 이미지 업로드 기능 제거됨
  
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _nameError;
  List<String> _selectedBadges = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _selectedBadges = List<String>.from(widget.user.badges ?? []);
    
    _nameController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasTextChanges = _nameController.text != widget.user.name;
    final hasBadgeChanges = !_listsEqual(_selectedBadges, widget.user.badges ?? []);
    final hasChanges = hasTextChanges || hasBadgeChanges;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }
  
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 이미지 업로드 기능 제거됨 - Phase 2에서 구현 예정

  Future<void> _editBadges() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => BadgeSelectionScreen(
          initialBadges: _selectedBadges,
          isOnboarding: false,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedBadges = result;
      });
      _onTextChanged(); // 변경사항 감지
    }
  }

  Future<void> _validateAndSave() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      setState(() {
        _nameError = '닉네임을 입력해주세요';
      });
      _nameFocus.requestFocus();
      return;
    }

    if (name.length < 2) {
      setState(() {
        _nameError = '닉네임은 2글자 이상이어야 합니다';
      });
      _nameFocus.requestFocus();
      return;
    }

    if (name.length > 20) {
      setState(() {
        _nameError = '닉네임은 20글자 이하여야 합니다';
      });
      _nameFocus.requestFocus();
      return;
    }

    setState(() {
      _nameError = null;
      _isLoading = true;
    });

    try {
      // 닉네임 중복 체크 (자신의 기존 닉네임이 아닌 경우만)
      if (name != widget.user.name) {
        final isDuplicate = await UserService.isNicknameExists(name);
        if (isDuplicate) {
          setState(() {
            _nameError = '이미 사용 중인 닉네임입니다';
            _isLoading = false;
          });
          _nameFocus.requestFocus();
          return;
        }
      }

      // 사용자 정보 업데이트
      final updatedUser = widget.user.copyWith(
        name: name,
        badges: _selectedBadges,
        updatedAt: DateTime.now(),
      );

      await UserService.updateUserFromObject(updatedUser);

      if (kDebugMode) {
        print('✅ 프로필 업데이트 성공: ${updatedUser.name}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('프로필이 업데이트되었습니다'),
            backgroundColor: AppDesignTokens.primary,
          ),
        );
        Navigator.pop(context, true); // true를 반환하여 업데이트 되었음을 알림
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 프로필 업데이트 실패: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 업데이트에 실패했습니다'),
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

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항 취소'),
        content: const Text('작성한 내용이 삭제됩니다. 정말 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              Navigator.pop(context); // 편집 화면 닫기
            },
            child: Text(
              '나가기',
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text(
          '프로필 편집',
          style: AppTextStyles.titleLarge,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_hasChanges) {
              _showDiscardDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _validateAndSave,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '저장',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppDesignTokens.primary,
                        fontWeight: AppDesignTokens.fontWeightBold,
                      ),
                    ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 사진 섹션 (가운데 정렬 및 편집 가능)
            _buildCenteredProfileImageSection(),
            
            const SizedBox(height: 16),
            
            // 기본 정보 섹션
            _buildBasicInfoSection(),
            
            const SizedBox(height: 16),
            
            // 뱃지 섹션
            _buildBadgeSection(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredProfileImageSection() {
    // 가운데 정렬된 프로필 사진 섹션 (편집 가능)
    ImageProvider? imageProvider;
    if (widget.user.profileImageUrl != null && widget.user.profileImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(widget.user.profileImageUrl!);
    }

    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppDesignTokens.primary,
                          fontSize: 32,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppDesignTokens.background,
                      width: 3,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      // TODO: 이미지 선택 기능 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('프로필 사진 편집 기능은 추후 추가 예정입니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '프로필 사진 변경',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppDesignTokens.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기본 정보',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          
          // 닉네임 입력
          Text(
            '닉네임',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: AppDesignTokens.fontWeightSemiBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing1),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            decoration: InputDecoration(
              hintText: '닉네임을 입력하세요',
              errorText: _nameError,
              border: OutlineInputBorder(
                borderRadius: AppBorderRadius.medium,
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppBorderRadius.medium,
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppBorderRadius.medium,
                borderSide: BorderSide(
                  color: AppDesignTokens.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppBorderRadius.medium,
                borderSide: const BorderSide(
                  color: Colors.red,
                ),
              ),
              contentPadding: AppPadding.all16,
              counterText: '',
              helperText: '',
              isDense: true,
            ),
            maxLength: 20,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 8),
          Text(
            '다른 사용자에게 표시되는 이름입니다',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBadgeSection() {
    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '뱃지',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
              TextButton(
                onPressed: _editBadges,
                child: Text(
                  '편집',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppDesignTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing2),
          if (_selectedBadges.isEmpty)
            Container(
              width: double.infinity,
              padding: AppPadding.all16,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: AppBorderRadius.medium,
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                '아직 선택된 뱃지가 없습니다.\n편집 버튼을 눌러 나만의 특성을 선택해보세요!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedBadges.map((badgeId) {
                final badge = UserBadge.getBadgeById(badgeId);
                if (badge == null) return const SizedBox.shrink();
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppDesignTokens.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        badge.emoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badge.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppDesignTokens.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: AppDesignTokens.spacing1),
          Text(
            '최대 3개까지 선택할 수 있어요',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}