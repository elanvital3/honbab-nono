import 'package:flutter/material.dart';
import '../styles/text_styles.dart';
import '../constants/app_design_tokens.dart';
import '../models/meeting.dart';
import '../screens/evaluation/user_evaluation_screen.dart';
import '../services/notification_service.dart';

class EvaluationRequestDialog extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onEvaluationCompleted;

  const EvaluationRequestDialog({
    super.key,
    required this.meeting,
    this.onEvaluationCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.all(24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      backgroundColor: Colors.white,
      elevation: 8,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppDesignTokens.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star,
              color: AppDesignTokens.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '모임 평가 요청',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 모임 정보 - 심플하게
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  meeting.restaurantName ?? meeting.location,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  meeting.formattedDateTime,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppDesignTokens.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 메시지 - 심플하게
          Text(
            '모임이 완료되었습니다! 🎉',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppDesignTokens.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          Text(
            '다른 참여자들을 평가해주세요',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppDesignTokens.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        Column(
          children: [
            // 메인 버튼 - 평가하러 가기
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToEvaluation(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '평가하러 가기',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 보조 버튼 - 나중에
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _scheduleReminderNotification();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  '하루 후 다시 알림',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppDesignTokens.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToEvaluation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserEvaluationScreen(
          meetingId: meeting.id,
          meeting: meeting,
        ),
      ),
    ).then((_) {
      // 평가 완료 후 콜백 호출
      onEvaluationCompleted?.call();
    });
  }
  
  /// 24시간 후 재알림 예약
  void _scheduleReminderNotification() {
    try {
      NotificationService().scheduleEvaluationReminder(
        meeting: meeting,
        delayHours: 24,
      );
    } catch (e) {
      // 알림 예약 실패해도 다이얼로그는 정상적으로 닫힘
      print('⚠️ 평가 재알림 예약 실패: $e');
    }
  }

  /// 평가 요청 다이얼로그를 표시합니다.
  static Future<void> show({
    required BuildContext context,
    required Meeting meeting,
    VoidCallback? onEvaluationCompleted,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // 뒤로가기로 닫기 방지
      builder: (context) => EvaluationRequestDialog(
        meeting: meeting,
        onEvaluationCompleted: onEvaluationCompleted,
      ),
    );
  }
}