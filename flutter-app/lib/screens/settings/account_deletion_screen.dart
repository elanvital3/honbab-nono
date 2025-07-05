import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../services/auth_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  String? _selectedReason;
  bool _isDeleting = false;
  
  final List<String> _deletionReasons = [
    '서비스를 더 이상 이용하지 않음',
    '개인정보 보호가 우려됨',
    '다른 서비스를 이용하고 싶음',
    '앱 사용이 불편함',
    '기타'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text('계정 삭제', style: AppTextStyles.titleLarge),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경고 섹션
            _buildWarningSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 삭제될 데이터 설명
            _buildDataDeletionSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 탈퇴 사유 선택 (선택사항)
            _buildReasonSection(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
            
            // 삭제 버튼
            _buildDeletionButton(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningSection() {
    return CommonCard(
      margin: AppPadding.all16,
      padding: AppPadding.all20,
      color: Colors.red.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '계정 삭제 주의사항',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          Text(
            '• 계정 삭제 시 모든 데이터가 영구적으로 삭제됩니다\n'
            '• 삭제된 데이터는 복구할 수 없습니다\n'
            '• 진행 중인 모임이 있다면 자동으로 취소됩니다\n'
            '• 재가입 시 일정 기간 제한이 있을 수 있습니다',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.red.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataDeletionSection() {
    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_forever,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '삭제될 데이터',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          
          _buildDataItem('프로필 정보', '닉네임, 프로필 사진, 자기소개 등'),
          _buildDataItem('모임 기록', '주최한 모임, 참여한 모임 기록'),
          _buildDataItem('평가 기록', '받은 평가, 준 평가 모두 삭제'),
          _buildDataItem('채팅 기록', '채팅 내용은 익명처리되어 보존'),
          _buildDataItem('즐겨찾기', '즐겨찾기한 식당 목록'),
        ],
      ),
    );
  }

  Widget _buildDataItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppDesignTokens.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: AppDesignTokens.fontWeightMedium,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing1),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.feedback_outlined,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '탈퇴 사유 (선택사항)',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing2),
          Text(
            '서비스 개선을 위해 탈퇴 사유를 알려주세요',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          
          ..._deletionReasons.map((reason) => _buildReasonOption(reason)),
        ],
      ),
    );
  }

  Widget _buildReasonOption(String reason) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing1),
      child: RadioListTile<String>(
        title: Text(
          reason,
          style: AppTextStyles.bodyMedium,
        ),
        value: reason,
        groupValue: _selectedReason,
        activeColor: AppDesignTokens.primary,
        contentPadding: EdgeInsets.zero,
        onChanged: (value) {
          setState(() {
            _selectedReason = value;
          });
        },
      ),
    );
  }

  Widget _buildDeletionButton() {
    return Padding(
      padding: AppPadding.horizontal16,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isDeleting ? null : _showDeletionConfirmDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.red.shade600,
                    width: 1,
                  ),
                ),
              ),
              child: _isDeleting 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '계정 삭제 중...',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Text(
                          '계정 삭제하기',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing2),
          Text(
            '계정 삭제는 되돌릴 수 없습니다. 신중히 결정해주세요.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDeletionConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: AppDesignTokens.spacing2),
            Text(
              '정말 삭제하시겠습니까?',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: AppDesignTokens.fontWeightBold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDesignTokens.spacing2),
            Text(
              '계정과 모든 관련 데이터가 영구적으로 삭제됩니다.',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: AppDesignTokens.fontWeightMedium,
              ),
            ),
            if (_selectedReason != null) ...[
              const SizedBox(height: AppDesignTokens.spacing3),
              Container(
                padding: AppPadding.all12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppBorderRadius.medium,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택한 탈퇴 사유:',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: AppDesignTokens.spacing1),
                    Text(
                      _selectedReason!,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: AppTextStyles.labelLarge.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: Text(
              '삭제',
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.red.shade600,
                fontWeight: AppDesignTokens.fontWeightBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      // 현재 사용자 확인
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      // 진행 상황 다이얼로그 표시
      _showProgressDialog();

      // 계정 삭제 실행
      await AuthService.deleteAccount(reason: _selectedReason);

      // 성공 시 진행 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context); // 진행 다이얼로그 닫기
        _showSuccessDialog();
      }
    } catch (e) {
      // 실패 시 진행 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context); // 진행 다이얼로그 닫기
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppDesignTokens.spacing3),
            Text(
              '계정을 삭제하고 있습니다...',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesignTokens.spacing2),
            Text(
              '잠시만 기다려주세요.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 24,
            ),
            const SizedBox(width: AppDesignTokens.spacing2),
            Text(
              '삭제 완료',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: AppDesignTokens.fontWeightBold,
              ),
            ),
          ],
        ),
        content: Text(
          '계정이 성공적으로 삭제되었습니다.\n그동안 혼밥노노를 이용해주셔서 감사합니다.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 앱 재시작을 위해 모든 화면 닫기
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              '확인',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppDesignTokens.primary,
                fontWeight: AppDesignTokens.fontWeightBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: AppDesignTokens.spacing2),
            Text(
              '삭제 실패',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: AppDesignTokens.fontWeightBold,
              ),
            ),
          ],
        ),
        content: Text(
          '계정 삭제 중 오류가 발생했습니다.\n다시 시도해주세요.\n\n오류: $error',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '확인',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppDesignTokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}