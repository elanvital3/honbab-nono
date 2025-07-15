import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_evaluation.dart';
import '../../models/user.dart';
import '../../models/meeting.dart';
import '../../models/restaurant_evaluation.dart';
import '../../services/evaluation_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/restaurant_evaluation_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';
import '../../components/common/common_confirm_dialog.dart';
import '../../components/participant_evaluation_card.dart';

class UserEvaluationScreen extends StatefulWidget {
  final String meetingId;
  final Meeting meeting;

  const UserEvaluationScreen({
    super.key,
    required this.meetingId,
    required this.meeting,
  });

  @override
  State<UserEvaluationScreen> createState() => _UserEvaluationScreenState();
}

class _UserEvaluationScreenState extends State<UserEvaluationScreen> {
  List<Map<String, dynamic>> _evaluationData = []; // 평가 대상자와 기존 평가 정보
  List<User> _pendingEvaluationUsers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _currentUserId;

  // 각 사용자별 평가 데이터
  Map<String, int> _punctualityRatings = {};
  Map<String, int> _mannersRatings = {};
  Map<String, int> _meetAgainRatings = {};
  Map<String, String> _comments = {};
  
  // 기존 평가 여부 추적
  Map<String, bool> _hasExistingEvaluation = {};

  // 식당 평가 데이터
  int _restaurantRating = 5;
  String _restaurantComment = '';

  @override
  void initState() {
    super.initState();
    _loadPendingEvaluations();
  }

  Future<void> _loadPendingEvaluations() async {
    try {
      _currentUserId = AuthService.currentUser?.uid;
      if (_currentUserId == null) {
        _showErrorAndClose('로그인이 필요합니다');
        return;
      }

      // 평가 대상자와 기존 평가 정보 조회 (새로운 1대1 평가 시스템)
      final evaluationData = await EvaluationService.getPendingEvaluations(
        widget.meetingId,
        _currentUserId!,
      );

      if (evaluationData.isEmpty) {
        _showCompletionDialog();
        return;
      }

      // 사용자 정보 조회 및 평가 데이터 설정
      final users = <User>[];
      for (final data in evaluationData) {
        final userId = data['userId'] as String;
        final hasExisting = data['hasExistingEvaluation'] as bool;
        final existingEvaluation = data['existingEvaluation'] as UserEvaluation?;
        
        final user = await UserService.getUser(userId);
        if (user != null) {
          users.add(user);
          _hasExistingEvaluation[userId] = hasExisting;
          
          if (hasExisting && existingEvaluation != null) {
            // 기존 평가 데이터 로드
            _punctualityRatings[userId] = existingEvaluation.punctualityRating;
            _mannersRatings[userId] = existingEvaluation.friendlinessRating;
            _meetAgainRatings[userId] = existingEvaluation.communicationRating;
            _comments[userId] = existingEvaluation.comment ?? '';
          } else {
            // 기본값 설정
            _punctualityRatings[userId] = 5;
            _mannersRatings[userId] = 5;
            _meetAgainRatings[userId] = 5;
            _comments[userId] = '';
          }
        }
      }

      setState(() {
        _evaluationData = evaluationData;
        _pendingEvaluationUsers = users;
        _isLoading = false;
      });

      if (kDebugMode) {
        print('✅ 평가 대상자 로드 완료: ${users.length}명');
        print('   - 신규 평가: ${users.where((user) => !_hasExistingEvaluation[user.id]!).length}명');
        print('   - 수정 가능: ${users.where((user) => _hasExistingEvaluation[user.id]!).length}명');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 대상자 로드 실패: $e');
      }
      _showErrorAndClose('평가 정보를 불러오는데 실패했습니다');
    }
  }

  void _showCompletionDialog() {
    final hasAnyNewEvaluations = _hasExistingEvaluation.values.any((hasExisting) => !hasExisting);
    final hasAnyExistingEvaluations = _hasExistingEvaluation.values.any((hasExisting) => hasExisting);
    
    String message;
    if (hasAnyNewEvaluations && hasAnyExistingEvaluations) {
      message = '이미 모든 참여자를 평가하셨습니다.\n기존 평가를 수정하실 수 있습니다! ✨';
    } else if (hasAnyExistingEvaluations) {
      message = '이미 모든 참여자를 평가하셨습니다.\n언제든 평가를 수정하실 수 있어요! ✨';
    } else {
      message = '모든 참여자에 대한 평가가 완료되었습니다.\n참여해주셔서 감사합니다! 🎉';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommonConfirmDialog(
        title: '평가 완료',
        content: message,
        icon: Icons.celebration,
        iconColor: AppDesignTokens.primary,
        confirmText: '확인',
        showCancelButton: false,
        onConfirm: () {
          Navigator.pop(context); // Dialog 닫기
          Navigator.popUntil(context, (route) => route.isFirst); // 홈으로 이동
        },
      ),
    );
  }

  void _showErrorAndClose(String message) {
    showDialog(
      context: context,
      builder: (context) => CommonConfirmDialog(
        title: '오류',
        content: message,
        icon: Icons.error_outline,
        iconColor: Colors.red[400],
        confirmText: '확인',
        confirmTextColor: Colors.red[400],
        showCancelButton: false,
        onConfirm: () {
          Navigator.pop(context); // Dialog 닫기
          Navigator.pop(context); // Screen 닫기
        },
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // 평가가 완료되지 않았다면 경고 다이얼로그 표시
    return await CommonConfirmDialog.showWarning(
      context: context,
      title: '평가 미완료',
      content: '참여자 평가를 완료해야 모임이 완료됩니다.\n\n정말로 나가시겠습니까?\n나중에 다시 평가할 수 있습니다.',
      cancelText: '계속 평가하기',
      confirmText: '나중에 하기',
    );
  }

  Future<void> _submitAllEvaluations() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // 식당 평가 제출 (식당 ID가 있는 경우에만)
      if (widget.meeting.restaurantId != null && widget.meeting.restaurantId!.isNotEmpty) {
        final restaurantEvaluation = RestaurantEvaluation(
          id: '',
          restaurantId: widget.meeting.restaurantId!,
          restaurantName: widget.meeting.restaurantName ?? widget.meeting.location,
          evaluatorId: _currentUserId!,
          meetingId: widget.meetingId,
          rating: _restaurantRating,
          comment: _restaurantComment.trim().isEmpty ? null : _restaurantComment.trim(),
        );

        await RestaurantEvaluationService.submitRestaurantEvaluation(restaurantEvaluation);
        if (kDebugMode) {
          print('✅ 식당 평가 제출 완료');
        }
      }

      // 모든 사용자 평가 제출
      for (final user in _pendingEvaluationUsers) {
        final evaluation = UserEvaluation(
          id: '',
          meetingId: widget.meetingId,
          evaluatorId: _currentUserId!,
          evaluatedUserId: user.id,
          punctualityRating: _punctualityRatings[user.id] ?? 5,
          friendlinessRating: _mannersRatings[user.id] ?? 5,
          communicationRating: _meetAgainRatings[user.id] ?? 5,
          comment: _comments[user.id]?.trim().isEmpty == true ? null : _comments[user.id]?.trim(),
          // 모임 정보 추가
          meetingLocation: widget.meeting.location,
          meetingRestaurant: widget.meeting.restaurantName,
          meetingDateTime: widget.meeting.dateTime,
        );

        await EvaluationService.submitEvaluation(evaluation);
      }

      if (kDebugMode) {
        print('✅ 모든 평가 제출 완료: ${_pendingEvaluationUsers.length}명');
      }

      // 평가 완료 시 재알림 취소
      try {
        await NotificationService().cancelEvaluationReminder(widget.meetingId);
        if (kDebugMode) {
          print('✅ 평가 재알림 취소 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 평가 재알림 취소 실패: $e');
        }
        // 재알림 취소 실패해도 평가 완료 처리는 계속 진행
      }

      // 완료 다이얼로그 표시
      _showCompletionDialog();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (kDebugMode) {
        print('❌ 평가 제출 실패: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('평가 제출에 실패했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  int get _completedEvaluationsCount {
    return _pendingEvaluationUsers.where((user) {
      return _punctualityRatings[user.id] != null &&
             _mannersRatings[user.id] != null &&
             _meetAgainRatings[user.id] != null;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppDesignTokens.surfaceContainer,
        appBar: AppBar(
          title: Text(
            '모임 평가',
            style: AppTextStyles.titleLarge,
          ),
          backgroundColor: AppDesignTokens.background,
          foregroundColor: AppDesignTokens.onSurface,
          elevation: 0,
          actions: [
            if (!_isLoading && _pendingEvaluationUsers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$_completedEvaluationsCount/${_pendingEvaluationUsers.length}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppDesignTokens.primary,
                  ),
                )
              : _pendingEvaluationUsers.isEmpty
                  ? const Center(
                      child: Text('평가할 사용자가 없습니다'),
                    )
                  : _buildEvaluationForm(),
        ),
      ),
    );
  }

  Widget _buildEvaluationForm() {
    return Column(
      children: [
        // 평가 리스트 (모임 정보 + 평가 카드들)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pendingEvaluationUsers.length + 2, // +1 for meeting info, +1 for restaurant evaluation
            itemBuilder: (context, index) {
              // 첫 번째 아이템: 모임 정보
              if (index == 0) {
                return CommonCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant,
                            color: AppDesignTokens.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '모임 정보',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.meeting.description,
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${widget.meeting.restaurantName}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // 두 번째 아이템: 식당 평가
              if (index == 1) {
                return _buildRestaurantEvaluationCard();
              }
              
              // 나머지 아이템들: 사용자 평가 카드들
              final userIndex = index - 2; // -2 because of meeting info and restaurant evaluation
              final user = _pendingEvaluationUsers[userIndex];
              return ParticipantEvaluationCard(
                user: user,
                punctualityRating: _punctualityRatings[user.id] ?? 5,
                mannersRating: _mannersRatings[user.id] ?? 5,
                meetAgainRating: _meetAgainRatings[user.id] ?? 5,
                comment: _comments[user.id] ?? '',
                hasExistingEvaluation: _hasExistingEvaluation[user.id] ?? false,
                onPunctualityChanged: (rating) {
                  setState(() {
                    _punctualityRatings[user.id] = rating;
                  });
                },
                onMannersChanged: (rating) {
                  setState(() {
                    _mannersRatings[user.id] = rating;
                  });
                },
                onMeetAgainChanged: (rating) {
                  setState(() {
                    _meetAgainRatings[user.id] = rating;
                  });
                },
                onCommentChanged: (comment) {
                  setState(() {
                    _comments[user.id] = comment;
                  });
                },
              );
            },
          ),
        ),
        
        // 제출 버튼
        Container(
          width: double.infinity,
          color: AppDesignTokens.background,
          padding: const EdgeInsets.all(16),
          child: CommonButton(
            text: _isSubmitting ? '제출 중...' : '전체 평가 제출',
            onPressed: _isSubmitting ? null : _submitAllEvaluations,
            variant: ButtonVariant.primary,
            isLoading: _isSubmitting,
            fullWidth: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantEvaluationCard() {
    return CommonCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '식당 평가',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.meeting.restaurantName ?? widget.meeting.location,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // 별점 평가
          Row(
            children: [
              Text(
                '평점',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _restaurantRating = starIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        starIndex <= _restaurantRating ? Icons.star : Icons.star_border,
                        color: starIndex <= _restaurantRating 
                          ? AppDesignTokens.primary 
                          : Colors.grey[300],
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              Text(
                '$_restaurantRating점',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppDesignTokens.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 코멘트 입력
          Text(
            '한줄평 (선택사항)',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            maxLines: 2,
            maxLength: 100,
            onChanged: (value) {
              _restaurantComment = value;
            },
            decoration: InputDecoration(
              hintText: '식당에 대한 솔직한 후기를 남겨주세요',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[400],
              ),
              filled: true,
              fillColor: AppDesignTokens.surfaceContainer.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: AppTextStyles.caption.copyWith(
                color: Colors.grey[400],
              ),
            ),
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}