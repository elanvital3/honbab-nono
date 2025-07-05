import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_badge.dart';
import '../../models/user.dart' as app_user;
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_button.dart';

class BadgeSelectionScreen extends StatefulWidget {
  final List<String> initialBadges;
  final bool isOnboarding; // 회원가입 시 true, 프로필 편집 시 false

  const BadgeSelectionScreen({
    super.key,
    this.initialBadges = const [],
    this.isOnboarding = false,
  });

  @override
  State<BadgeSelectionScreen> createState() => _BadgeSelectionScreenState();
}

class _BadgeSelectionScreenState extends State<BadgeSelectionScreen> {
  final Set<String> _selectedBadgeIds = <String>{};
  bool _isLoading = false;
  static const int _maxBadges = 3; // 최대 선택 가능한 뱃지 수

  @override
  void initState() {
    super.initState();
    _selectedBadgeIds.addAll(widget.initialBadges);
  }

  Future<void> _saveBadges() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = AuthService.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 사용자 뱃지 업데이트
      await UserService.updateUser(currentUserId, {
        'badges': _selectedBadgeIds.toList(),
        'updatedAt': DateTime.now(),
      });

      if (kDebugMode) {
        print('✅ 사용자 뱃지 업데이트 완료: ${_selectedBadgeIds.toList()}');
      }

      if (mounted) {
        if (widget.isOnboarding) {
          // 회원가입 시에는 홈 화면으로 이동
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        } else {
          // 프로필 편집 시에는 이전 화면으로 돌아가기
          Navigator.pop(context, _selectedBadgeIds.toList());
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('특성 뱃지가 저장되었습니다! ✨'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 뱃지 저장 실패: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('뱃지 저장에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? '나의 특성 선택하기' : '특성 뱃지 편집'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: widget.isOnboarding
            ? null // 회원가입 시에는 뒤로가기 버튼 숨김
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠
          Column(
            children: [
              // 상단 설명
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: AppDesignTokens.primary.withOpacity(0.05),
                child: Column(
                  children: [
                    Icon(
                      Icons.star,
                      color: AppDesignTokens.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isOnboarding
                          ? '당신의 특성을 알려주세요!'
                          : '특성 뱃지를 수정하세요',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '최대 $_maxBadges개까지 선택할 수 있어요\n모임에서 다른 사용자들이 나를 더 잘 알 수 있어요',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '선택됨: ${_selectedBadgeIds.length}/$_maxBadges',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // 뱃지 리스트 (스크롤 없이 모든 카테고리를 펼쳐서 표시)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // 하단 여백 추가
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: UserBadge.allCategories.map((category) {
                      final badges = UserBadge.getBadgesByCategory(category);
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 카테고리 제목
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              category,
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // 뱃지들을 Wrap으로 자연스럽게 배치
                          Wrap(
                            spacing: 8, // 가로 간격
                            runSpacing: 8, // 세로 간격
                            children: badges.map((badge) {
                              final isSelected = _selectedBadgeIds.contains(badge.id);
                              
                              return GestureDetector(
                                onTap: () => _toggleBadge(badge.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                          fontSize: 16,
                                          fontFamily: null, // System emoji font
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        badge.name,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? AppDesignTokens.primary
                                              : Colors.black87,
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

                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          // 하단 버튼 (위치 고정)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommonButton(
                    text: _isLoading
                        ? '저장 중...'
                        : widget.isOnboarding
                            ? '완료하고 시작하기'
                            : '저장하기',
                    onPressed: _isLoading ? null : _saveBadges,
                    variant: ButtonVariant.primary,
                    fullWidth: true,
                    isLoading: _isLoading,
                  ),
                  if (widget.isOnboarding) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/home',
                                (route) => false,
                              );
                            },
                      child: Text(
                        '나중에 설정하기',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}