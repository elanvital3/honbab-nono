import 'package:flutter/material.dart';
import '../../styles/text_styles.dart';

class CommonConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final Color? confirmTextColor;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  const CommonConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.confirmTextColor,
    this.onCancel,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTextStyles.titleLarge),
      content: Text(content, style: AppTextStyles.bodyLarge),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.pop(context, false),
          child: Text(cancelText, style: AppTextStyles.labelLarge),
        ),
        TextButton(
          onPressed: onConfirm ?? () => Navigator.pop(context, true),
          child: Text(
            confirmText,
            style: AppTextStyles.labelLarge.copyWith(
              color: confirmTextColor ?? Theme.of(context).colorScheme.primary,
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