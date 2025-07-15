import 'package:flutter/material.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class CommonLoadingDialog extends StatelessWidget {
  final String? message;
  final double? progress; // null이면 무한 로딩, 0.0~1.0이면 진행률 표시
  final bool showProgressText; // 진행률 텍스트 표시 여부
  
  const CommonLoadingDialog({
    super.key,
    this.message,
    this.progress,
    this.showProgressText = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒷키로 닫기 방지
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 로딩 인디케이터
            SizedBox(
              width: 56,
              height: 56,
              child: progress != null
                  ? CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: AppDesignTokens.outline.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppDesignTokens.primary,
                      ),
                    )
                  : CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppDesignTokens.primary,
                      ),
                    ),
            ),
            
            const SizedBox(height: 20),
            
            // 메시지
            if (message != null)
              Text(
                message!,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppDesignTokens.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
            // 진행률 텍스트
            if (showProgressText && progress != null) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress! * 100).toInt()}%',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppDesignTokens.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 간단한 로딩 다이얼로그를 표시합니다.
  static void show({
    required BuildContext context,
    String? message = '잠시만 기다려주세요...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommonLoadingDialog(
        message: message,
      ),
    );
  }

  /// 진행률을 표시하는 로딩 다이얼로그를 표시합니다.
  static void showProgress({
    required BuildContext context,
    String? message,
    required double progress,
    bool showProgressText = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommonLoadingDialog(
        message: message,
        progress: progress,
        showProgressText: showProgressText,
      ),
    );
  }

  /// 현재 표시된 로딩 다이얼로그를 닫습니다.
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// 비동기 작업과 함께 로딩 다이얼로그를 표시하고 작업 완료 시 자동으로 닫습니다.
  static Future<T> showWithTask<T>({
    required BuildContext context,
    required Future<T> task,
    String? message = '잠시만 기다려주세요...',
  }) async {
    show(context: context, message: message);
    
    try {
      final result = await task;
      if (context.mounted) {
        hide(context);
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        hide(context);
      }
      rethrow;
    }
  }
}