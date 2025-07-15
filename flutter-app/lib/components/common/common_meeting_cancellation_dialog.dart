import 'package:flutter/material.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class CommonMeetingCancellationDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String message;
  final String cancelText;
  final String confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  
  const CommonMeetingCancellationDialog({
    super.key,
    this.title = '모임 취소',
    this.subtitle = '참여자가 없습니다',
    this.message = '참여자가 없어서 모임을 취소하시겠습니까?',
    this.cancelText = '모집 대기',
    this.confirmText = '지금 취소',
    this.onCancel,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_outlined,
              color: Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
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
          // 서브타이틀
          Text(
            subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // 메시지
          Text(
            message,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppDesignTokens.onSurface,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            // 모집 대기 버튼
            Expanded(
              child: TextButton(
                onPressed: onCancel ?? () => Navigator.pop(context, 'wait'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppDesignTokens.outline.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Text(
                  cancelText,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppDesignTokens.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 지금 취소 버튼
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirm ?? () => Navigator.pop(context, 'cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.red[200]!,
                    ),
                  ),
                ),
                child: Text(
                  confirmText,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.red[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 모임 취소 선택 다이얼로그를 표시합니다.
  /// 반환값: 'cancel', 'wait' 중 하나
  static Future<String?> show({
    required BuildContext context,
    String title = '모임 취소',
    String subtitle = '참여자가 없습니다',
    String message = '참여자가 없어서 모임을 취소하시겠습니까?',
    String cancelText = '모집 대기',
    String confirmText = '지금 취소',
  }) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommonMeetingCancellationDialog(
        title: title,
        subtitle: subtitle,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
    
    return result;
  }
}