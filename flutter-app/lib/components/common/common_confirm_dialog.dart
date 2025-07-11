import 'package:flutter/material.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class CommonConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final Color? confirmTextColor;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final IconData? icon;
  final Color? iconColor;
  final bool showCancelButton;

  const CommonConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.confirmTextColor,
    this.onCancel,
    this.onConfirm,
    this.icon,
    this.iconColor,
    this.showCancelButton = true,
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
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (iconColor ?? AppDesignTokens.primary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppDesignTokens.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.onSurface,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
      content: Text(
        content,
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppDesignTokens.onSurfaceVariant,
          height: 1.5,
        ),
        textAlign: TextAlign.left,
      ),
      actions: [
        if (showCancelButton)
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
                    backgroundColor: confirmTextColor ?? AppDesignTokens.primary,
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
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm ?? () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmTextColor ?? AppDesignTokens.primary,
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
    );
  }

  /// 간단한 확인 다이얼로그를 표시하고 결과를 반환합니다.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String cancelText = '취소',
    String confirmText = '확인',
    Color? confirmTextColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CommonConfirmDialog(
        title: title,
        content: content,
        cancelText: cancelText,
        confirmText: confirmText,
        confirmTextColor: confirmTextColor,
      ),
    );
    
    return result ?? false;
  }

  /// 삭제 확인 다이얼로그 (빨간색 스타일)
  static Future<bool> showDelete({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '삭제',
  }) async {
    return show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText,
      confirmTextColor: Colors.red[400],
    );
  }

  /// 완료 확인 다이얼로그 (초록색 스타일)
  static Future<bool> showComplete({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '완료',
  }) async {
    return show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText,
      confirmTextColor: Colors.green[600],
    );
  }

  /// 경고 확인 다이얼로그 (주황색 스타일)
  static Future<bool> showWarning({
    required BuildContext context,
    required String title,
    required String content,
    String cancelText = '취소',
    String confirmText = '확인',
  }) async {
    return show(
      context: context,
      title: title,
      content: content,
      cancelText: cancelText,
      confirmText: confirmText,
      confirmTextColor: Colors.orange[600],
    );
  }
}