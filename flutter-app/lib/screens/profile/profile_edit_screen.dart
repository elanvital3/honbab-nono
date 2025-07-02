import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _bioFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isUploadingImage = false;
  String? _nameError;
  String? _selectedImagePath;
  String? _uploadedImageUrl;
  List<String> _selectedBadges = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _bioController.text = widget.user.bio ?? '';
    _selectedBadges = List<String>.from(widget.user.badges ?? []);
    
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
    final hasTextChanges = _nameController.text != widget.user.name ||
                          _bioController.text != (widget.user.bio ?? '');
    final hasImageChanges = _selectedImagePath != null || _uploadedImageUrl != null;
    final hasBadgeChanges = !_listsEqual(_selectedBadges, widget.user.badges ?? []);
    final hasChanges = hasTextChanges || hasImageChanges || hasBadgeChanges;
    
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

  Future<void> _pickAndUploadImage() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _selectedImagePath = image.path;
        _isUploadingImage = true;
      });

      // Firebase Storage에 업로드
      final String fileName = 'profile_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        print('✅ 프로필 이미지 업로드 완료: $downloadUrl');
      }

      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploadingImage = false;
      });

      _onTextChanged(); // 변경사항 감지

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('프로필 사진이 업로드되었습니다'),
          backgroundColor: AppDesignTokens.primary,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 이미지 업로드 실패: $e');
      }

      setState(() {
        _isUploadingImage = false;
        _selectedImagePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 사진 선택'),
        content: const Text('사진을 어떻게 선택하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('카메라'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('갤러리'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

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
      final profileImageUrl = _uploadedImageUrl ?? widget.user.profileImageUrl;
      final updatedUser = widget.user.copyWith(
        name: name,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        profileImageUrl: profileImageUrl,
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
            // 프로필 사진 섹션
            _buildProfileImageSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 기본 정보 섹션
            _buildBasicInfoSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 소개 섹션
            _buildBioSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 뱃지 섹션
            _buildBadgeSection(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    // 표시할 이미지 결정 (로컬 -> 업로드된 URL -> 기존 URL)
    ImageProvider? imageProvider;
    if (_selectedImagePath != null) {
      imageProvider = FileImage(File(_selectedImagePath!));
    } else if (_uploadedImageUrl != null) {
      imageProvider = NetworkImage(_uploadedImageUrl!);
    } else if (widget.user.profileImageUrl != null && widget.user.profileImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(widget.user.profileImageUrl!);
    }

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
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppDesignTokens.primary,
                        ),
                      )
                    : null,
              ),
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
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
                    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing2),
          Text(
            _isUploadingImage ? '업로드 중...' : '탭해서 프로필 사진 변경',
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
                '특성 뱃지',
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
                '아직 선택된 특성 뱃지가 없습니다.\n편집 버튼을 눌러 나만의 특성을 선택해보세요!',
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