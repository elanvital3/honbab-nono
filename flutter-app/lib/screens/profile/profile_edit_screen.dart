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
import '../../components/common/common_confirm_dialog.dart';
import '../../models/user_badge.dart';
import '../../services/kakao_auth_service.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isImageLoading = false;
  String? _nameError;
  List<String> _selectedBadges = [];
  String? _newProfileImageUrl;

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
    final hasImageChanges = _newProfileImageUrl != null;
    final hasChanges = hasTextChanges || hasBadgeChanges || hasImageChanges;
    
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

  /// 이미지 선택 및 업로드
  Future<void> _selectAndUploadImage() async {
    try {
      // 이미지 선택 옵션 다이얼로그 표시
      final String? sourceType = await _showImageSourceDialog();
      if (sourceType == null) return;

      setState(() {
        _isImageLoading = true;
      });

      if (sourceType == 'kakao') {
        // 카카오 프로필 이미지 가져오기
        await _resetToDefaultImage();
        return;
      }

      // 카메라/갤러리 이미지 선택
      final ImageSource source = sourceType == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() {
          _isImageLoading = false;
        });
        return;
      }

      // Firebase Storage에 업로드
      final imageUrl = await _uploadImageToFirebase(File(image.path));
      
      if (imageUrl != null) {
        setState(() {
          _newProfileImageUrl = imageUrl;
          _isImageLoading = false;
        });
        _onTextChanged(); // 변경사항 감지
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('프로필 사진이 업로드되었습니다'),
              backgroundColor: AppDesignTokens.primary,
            ),
          );
        }
      } else {
        setState(() {
          _isImageLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 업로드에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 이미지 선택/업로드 실패: $e');
      }
      
      setState(() {
        _isImageLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 처리에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 이미지 소스 선택 다이얼로그
  Future<String?> _showImageSourceDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 사진 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('카카오 프로필'),
              onTap: () => Navigator.pop(context, 'kakao'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 되돌리기 버튼 표시 여부 확인
  bool _shouldShowResetButton() {
    // 현재 이미지가 있을 때만 표시 (카카오에서 새로 가져올 수 있도록)
    final currentImageUrl = _newProfileImageUrl ?? widget.user.profileImageUrl;
    return currentImageUrl != null && currentImageUrl.isNotEmpty;
  }

  /// 카카오 프로필 사진으로 되돌리기
  Future<void> _resetToDefaultImage() async {
    try {
      setState(() {
        _isImageLoading = true;
      });

      // 카카오 계정에서 현재 프로필 이미지 가져오기
      String? kakaoProfileUrl = await _getKakaoProfileImage();
      
      if (kakaoProfileUrl != null && kakaoProfileUrl.isNotEmpty) {
        setState(() {
          _newProfileImageUrl = kakaoProfileUrl;
          _isImageLoading = false;
        });
        _onTextChanged(); // 변경사항 감지
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('카카오 프로필 사진으로 변경되었습니다'),
              backgroundColor: AppDesignTokens.primary,
            ),
          );
        }
      } else {
        // 카카오 이미지가 없으면 기본 아바타로 (빈 문자열로 설정)
        setState(() {
          _newProfileImageUrl = ''; // 빈 문자열로 설정하여 기본 아바타 표시
          _isImageLoading = false;
        });
        _onTextChanged();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('기본 아바타로 변경되었습니다'),
              backgroundColor: AppDesignTokens.primary,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isImageLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카카오 이미지를 가져올 수 없습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 카카오 계정에서 프로필 이미지 가져오기
  Future<String?> _getKakaoProfileImage() async {
    try {
      if (kDebugMode) {
        print('🔍 카카오 프로필 이미지 가져오기 시작');
      }
      
      // 1. 저장된 카카오 이미지가 있으면 사용
      if (widget.user.kakaoProfileImageUrl != null && widget.user.kakaoProfileImageUrl!.isNotEmpty) {
        if (kDebugMode) {
          print('✅ 저장된 카카오 이미지 사용: ${widget.user.kakaoProfileImageUrl}');
        }
        return widget.user.kakaoProfileImageUrl;
      }
      
      // 2. 실제 카카오 API 호출로 현재 프로필 이미지 가져오기
      final User kakaoUser = await UserApi.instance.me();
      final String? profileImageUrl = kakaoUser.kakaoAccount?.profile?.profileImageUrl;
      
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        if (kDebugMode) {
          print('✅ 카카오 API에서 이미지 가져옴: $profileImageUrl');
        }
        
        // 가져온 이미지를 User 모델에도 저장 (다음에 사용할 수 있도록)
        await _saveKakaoProfileImage(profileImageUrl);
        
        return profileImageUrl;
      } else {
        if (kDebugMode) {
          print('❌ 카카오 프로필 이미지가 없습니다');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 카카오 프로필 이미지 가져오기 실패: $e');
      }
      return null;
    }
  }

  /// 카카오 프로필 이미지 URL을 User 모델에 저장
  Future<void> _saveKakaoProfileImage(String imageUrl) async {
    try {
      await UserService.updateUserFromObject(
        widget.user.copyWith(
          kakaoProfileImageUrl: imageUrl,
          updatedAt: DateTime.now(),
        ),
      );
      if (kDebugMode) {
        print('✅ 카카오 프로필 이미지 URL 저장 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 카카오 프로필 이미지 URL 저장 실패: $e');
      }
    }
  }

  /// Firebase Storage에 이미지 업로드
  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      final fileName = 'profile_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('profile_images/$fileName');
      
      if (kDebugMode) {
        print('📤 이미지 업로드 시작: $fileName');
      }
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (kDebugMode) {
        print('✅ 이미지 업로드 완료: $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 이미지 업로드 실패: $e');
      }
      return null;
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
      // _newProfileImageUrl이 null이면 기존 이미지 유지, 빈 문자열이면 기본 아바타로 변경
      String? finalProfileImageUrl;
      if (_newProfileImageUrl != null) {
        finalProfileImageUrl = _newProfileImageUrl!.isEmpty ? null : _newProfileImageUrl;
      } else {
        finalProfileImageUrl = widget.user.profileImageUrl;
      }
      
      final updatedUser = widget.user.copyWith(
        name: name,
        badges: _selectedBadges,
        profileImageUrl: finalProfileImageUrl,
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

  void _showDiscardDialog() async {
    final result = await CommonConfirmDialog.show(
      context: context,
      title: '변경사항 취소',
      content: '작성한 내용이 삭제됩니다. 정말 나가시겠습니까?',
      cancelText: '계속 작성',
      confirmText: '나가기',
      confirmTextColor: Colors.red[600],
    );
    
    if (result && mounted) {
      Navigator.pop(context); // 편집 화면 닫기
    }
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
            
            // 기본 정보 섹션 (뱃지 포함)
            _buildBasicInfoSection(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredProfileImageSection() {
    // 현재 표시할 이미지 결정 (새 이미지가 있으면 우선 표시)
    ImageProvider? imageProvider;
    final imageUrl = _newProfileImageUrl ?? widget.user.profileImageUrl;
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    }

    return Container(
      width: double.infinity, // 가로 꽉 채우기
      margin: AppPadding.horizontal16,
      child: CommonCard(
        padding: AppPadding.all24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
          children: [
            Stack(
              children: [
                // 로딩 중일 때 표시할 오버레이
                if (_isImageLoading)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                else
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
                
                // 카메라 버튼
                if (!_isImageLoading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppDesignTokens.background,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: _selectAndUploadImage,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '프로필 사진 변경',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppDesignTokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '카메라 아이콘을 터치하여 사진을 변경하세요',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
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
          
          // 뱃지 섹션을 기본 정보 카드 안에 통합
          const SizedBox(height: AppDesignTokens.spacing4),
          Row(
            children: [
              Text(
                '뱃지',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: AppDesignTokens.fontWeightSemiBold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(최대 3개)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing2),
          _buildBadgeGrid(),
        ],
      ),
    );
  }

  Widget _buildBadgeGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: UserBadge.allBadges.map((badge) {
        final isSelected = _selectedBadges.contains(badge.id);
        
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
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _toggleBadge(String badgeId) {
    setState(() {
      if (_selectedBadges.contains(badgeId)) {
        _selectedBadges.remove(badgeId);
      } else {
        if (_selectedBadges.length < 3) {
          _selectedBadges.add(badgeId);
        } else {
          // 최대 3개 제한 알림
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('뱃지는 최대 3개까지 선택할 수 있습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
    _onTextChanged(); // 변경사항 감지
  }

}