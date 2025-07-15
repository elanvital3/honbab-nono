import 'package:flutter/material.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class CommonMeetingCompletionDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> checklistItems;
  final String? note;
  final String cancelText;
  final String confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  
  const CommonMeetingCompletionDialog({
    super.key,
    this.title = '모임 완료',
    this.subtitle = '모임을 완료하시겠습니까?',
    required this.checklistItems,
    this.note,
    this.cancelText = '취소',
    this.confirmText = '확인 및 평가하기',
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
              color: AppDesignTokens.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: AppDesignTokens.primary,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 서브타이틀
          Text(
            subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.onSurface,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 체크리스트
          ...checklistItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppDesignTokens.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppDesignTokens.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
          
          // 추가 노트
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onCancel ?? () => Navigator.pop(context, false),
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
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirm ?? () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  confirmText,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white,
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

  /// 모임 완료 확인 다이얼로그를 표시합니다.
  static Future<bool> show({
    required BuildContext context,
    String title = '모임 완료',
    String subtitle = '모임을 완료하시겠습니까?',
    required List<String> checklistItems,
    String? note,
    String cancelText = '취소',
    String confirmText = '확인 및 평가하기',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommonMeetingCompletionDialog(
        title: title,
        subtitle: subtitle,
        checklistItems: checklistItems,
        note: note,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
    
    return result ?? false;
  }
}