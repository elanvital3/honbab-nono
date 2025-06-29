import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';

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
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _bioFocus = FocusNode();
  
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _bioController.text = widget.user.bio ?? '';
    
    _nameController.addListener(_onTextChanged);
    _bioController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanges = _nameController.text != widget.user.name ||
                      _bioController.text != (widget.user.bio ?? '');
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
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
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
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
            // 프로필 사진 섹션
            _buildProfileImageSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 기본 정보 섹션
            _buildBasicInfoSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 소개 섹션
            _buildBioSection(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return CommonCard(
      margin: AppPadding.all16,
      padding: AppPadding.all20,
      child: Column(
        children: [
          Text(
            '프로필 사진',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
                backgroundImage: widget.user.profileImageUrl != null && 
                                widget.user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.user.profileImageUrl!)
                    : null,
                child: widget.user.profileImageUrl == null || 
                       widget.user.profileImageUrl!.isEmpty
                    ? Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppDesignTokens.primary,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppDesignTokens.background,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('프로필 사진 변경 기능 준비 중'),
                          backgroundColor: AppDesignTokens.primary,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing2),
          Text(
            '탭해서 프로필 사진 변경',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
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
            ),
            maxLength: 20,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _bioFocus.requestFocus(),
          ),
          const SizedBox(height: AppDesignTokens.spacing1),
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

  Widget _buildBioSection() {
    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '소개',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          TextField(
            controller: _bioController,
            focusNode: _bioFocus,
            decoration: InputDecoration(
              hintText: '자신을 소개해보세요 (선택사항)',
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
              contentPadding: AppPadding.all16,
              counterText: '',
            ),
            maxLines: 4,
            maxLength: 150,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppDesignTokens.spacing1),
          Text(
            '취미, 관심사, 좋아하는 음식 등을 자유롭게 작성해주세요',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}