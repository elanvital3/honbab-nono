import 'package:flutter/material.dart';
import '../constants/app_design_tokens.dart';
import '../styles/text_styles.dart';
import '../components/common/common_button.dart';

class MeetingAutoCompleteDialog extends StatefulWidget {
  final String meetingName;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onPostpone;
  final VoidCallback onCancelMeeting; // 모임 취소 콜백 추가
  final bool isManualCompletion; // 수동 완료 여부

  const MeetingAutoCompleteDialog({
    super.key,
    required this.meetingName,
    required this.onComplete,
    required this.onCancel,
    required this.onPostpone,
    required this.onCancelMeeting,
    this.isManualCompletion = false,
  });

  static Future<String?> show({
    required BuildContext context,
    required String meetingName,
    required VoidCallback onComplete,
    required VoidCallback onPostpone,
    required VoidCallback onCancelMeeting,
    bool isManualCompletion = false,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MeetingAutoCompleteDialog(
        meetingName: meetingName,
        onComplete: onComplete,
        onCancel: () => Navigator.pop(context, 'cancel'),
        onPostpone: onPostpone,
        onCancelMeeting: onCancelMeeting,
        isManualCompletion: isManualCompletion,
      ),
    );
  }

  @override
  State<MeetingAutoCompleteDialog> createState() => _MeetingAutoCompleteDialogState();
}

class _MeetingAutoCompleteDialogState extends State<MeetingAutoCompleteDialog> {
  bool _keepChatActive = false; // 채팅방 유지 옵션

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘과 제목
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppDesignTokens.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time,
                color: AppDesignTokens.primary,
                size: 32,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              '모임 시간이 지났습니다',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              widget.meetingName,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppDesignTokens.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              widget.isManualCompletion
                  ? '모임을 완료하시겠습니까?\n\n완료 후 참여자들에게 평가 요청 알림이 발송됩니다.'
                  : '모임이 완료되었나요?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // 채팅방 유지 옵션
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _keepChatActive,
                    onChanged: (value) {
                      setState(() {
                        _keepChatActive = value ?? false;
                      });
                    },
                    activeColor: AppDesignTokens.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '채팅방 유지하기',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '체크 시 모임 완료 후에도 채팅 가능',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 버튼들
            Column(
              children: [
                // 모임 완료 버튼 (primary)
                CommonButton(
                  text: '모임 완료',
                  onPressed: () {
                    Navigator.pop(context, _keepChatActive ? 'complete_keep' : 'complete_close');
                    widget.onComplete();
                  },
                  variant: ButtonVariant.primary,
                  fullWidth: true,
                ),
                
                const SizedBox(height: 12),
                
                // 아직 모임중이에요 버튼 (outline)
                CommonButton(
                  text: '아직 모임중이에요',
                  onPressed: () {
                    Navigator.pop(context, 'still_ongoing');
                    widget.onCancel();
                  },
                  variant: ButtonVariant.outline,
                  fullWidth: true,
                ),
                
                const SizedBox(height: 12),
                
                // 모임 취소 버튼 (destructive)
                CommonButton(
                  text: '모임 취소',
                  onPressed: () {
                    Navigator.pop(context, 'cancel_meeting');
                    widget.onCancelMeeting();
                  },
                  variant: ButtonVariant.destructive,
                  fullWidth: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}