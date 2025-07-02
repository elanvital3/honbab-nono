import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_evaluation.dart';
import '../../models/user.dart';
import '../../models/meeting.dart';
import '../../services/evaluation_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';

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
  List<String> _pendingEvaluationUserIds = [];
  List<User> _pendingEvaluationUsers = [];
  int _currentUserIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _currentUserId;

  // 현재 평가 중인 사용자의 평점
  int _punctualityRating = 5;
  int _mannersRating = 5;
  int _meetAgainRating = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPendingEvaluations();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingEvaluations() async {
    try {
      _currentUserId = AuthService.currentUser?.uid;
      if (_currentUserId == null) {
        _showErrorAndClose('로그인이 필요합니다');
        return;
      }

      // 평가해야 할 사용자 ID 목록 조회
      final pendingIds = await EvaluationService.getPendingEvaluations(
        widget.meetingId,
        _currentUserId!,
      );

      if (pendingIds.isEmpty) {
        _showCompletionDialog();
        return;
      }

      // 사용자 정보 조회
      final users = <User>[];
      for (final userId in pendingIds) {
        final user = await UserService.getUser(userId);
        if (user != null) {
          users.add(user);
        }
      }

      setState(() {
        _pendingEvaluationUserIds = pendingIds;
        _pendingEvaluationUsers = users;
        _isLoading = false;
      });

      if (kDebugMode) {
        print('✅ 평가 대상자 로드 완료: ${users.length}명');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 대상자 로드 실패: $e');
      }
      _showErrorAndClose('평가 정보를 불러오는데 실패했습니다');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('평가 완료'),
        content: const Text('모든 참여자에 대한 평가가 완료되었습니다.\n참여해주셔서 감사합니다! 🎉'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog 닫기
              Navigator.pop(context); // Screen 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorAndClose(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog 닫기
              Navigator.pop(context); // Screen 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCurrentEvaluation() async {
    if (_currentUserIndex >= _pendingEvaluationUsers.length) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = _pendingEvaluationUsers[_currentUserIndex];
      
      final evaluation = UserEvaluation(
        id: '',
        meetingId: widget.meetingId,
        evaluatorId: _currentUserId!,
        evaluatedUserId: currentUser.id,
        punctualityRating: _punctualityRating,
        friendlinessRating: _mannersRating,
        communicationRating: _meetAgainRating,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );

      await EvaluationService.submitEvaluation(evaluation);

      if (kDebugMode) {
        print('✅ 평가 제출 완료: ${currentUser.name}');
      }

      // 다음 사용자로 이동 또는 완료
      if (_currentUserIndex + 1 < _pendingEvaluationUsers.length) {
        setState(() {
          _currentUserIndex++;
          _resetRatings();
          _isSubmitting = false;
        });
      } else {
        // 모든 평가 완료
        _showCompletionDialog();
      }
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
        ),
      );
    }
  }

  void _resetRatings() {
    _punctualityRating = 5;
    _mannersRating = 5;
    _meetAgainRating = 5;
    _commentController.clear();
  }

  void _skipCurrentEvaluation() {
    if (_currentUserIndex + 1 < _pendingEvaluationUsers.length) {
      setState(() {
        _currentUserIndex++;
        _resetRatings();
      });
    } else {
      _showCompletionDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('참여자 평가'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_isLoading && _pendingEvaluationUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentUserIndex + 1}/${_pendingEvaluationUsers.length}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppDesignTokens.primary,
                    fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildEvaluationForm() {
    final currentUser = _pendingEvaluationUsers[_currentUserIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모임 정보
          CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '모임 정보',
                    style: AppTextStyles.headlineSmall,
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
            ),
          ),

          const SizedBox(height: 24),

          // 평가 대상자 정보
          CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: currentUser.profileImageUrl != null
                        ? NetworkImage(currentUser.profileImageUrl!)
                        : null,
                    backgroundColor: AppDesignTokens.primary.withOpacity(0.2),
                    child: currentUser.profileImageUrl == null
                        ? Text(
                            currentUser.name.isNotEmpty 
                                ? currentUser.name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppDesignTokens.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.name,
                          style: AppTextStyles.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        if (currentUser.rating > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                currentUser.rating.toStringAsFixed(1),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 평가 항목들
          Text(
            '평가 항목',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: 16),

          _buildRatingSection(
            title: '시간준수',
            subtitle: '약속한 시간에 맞춰 도착했나요?',
            rating: _punctualityRating,
            onChanged: (rating) => setState(() => _punctualityRating = rating),
          ),

          const SizedBox(height: 20),

          _buildRatingSection(
            title: '대화매너',
            subtitle: '대화하기 편하고 예의바른가요?',
            rating: _mannersRating,
            onChanged: (rating) => setState(() => _mannersRating = rating),
          ),

          const SizedBox(height: 20),

          _buildRatingSection(
            title: '재만남의향',
            subtitle: '다음에 또 만나고 싶나요?',
            rating: _meetAgainRating,
            onChanged: (rating) => setState(() => _meetAgainRating = rating),
          ),

          const SizedBox(height: 24),

          // 추가 코멘트
          Text(
            '추가 코멘트 (선택사항)',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '좋았던 점이나 개선할 점을 자유롭게 작성해주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),

          const SizedBox(height: 32),

          // 버튼들
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  text: '건너뛰기',
                  onPressed: _isSubmitting ? null : _skipCurrentEvaluation,
                  variant: ButtonVariant.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: CommonButton(
                  text: _isSubmitting ? '제출 중...' : '평가 제출',
                  onPressed: _isSubmitting ? null : _submitCurrentEvaluation,
                  variant: ButtonVariant.primary,
                  isLoading: _isSubmitting,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    required String subtitle,
    required int rating,
    required Function(int) onChanged,
  }) {
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return GestureDetector(
                  onTap: () => onChanged(starValue),
                  child: Icon(
                    Icons.star,
                    size: 36,
                    color: starValue <= rating
                        ? Colors.amber
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '매우 아쉬워요',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '매우 좋았어요',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}