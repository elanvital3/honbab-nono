import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting.dart';
import '../../models/user.dart' as app_user;
import '../../services/meeting_service.dart';
import '../../services/user_service.dart';
import '../profile/user_profile_screen.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';
import '../../components/common/common_confirm_dialog.dart';

class ApplicantManagementScreen extends StatefulWidget {
  final Meeting meeting;

  const ApplicantManagementScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<ApplicantManagementScreen> createState() => _ApplicantManagementScreenState();
}

class _ApplicantManagementScreenState extends State<ApplicantManagementScreen> {
  List<app_user.User> _pendingApplicants = [];
  List<app_user.User> _participants = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadApplicantsAndParticipants();
  }

  Future<void> _loadApplicantsAndParticipants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 실시간 모임 정보 가져오기
      final currentMeeting = await MeetingService.getMeeting(widget.meeting.id);
      if (currentMeeting == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // 승인 대기자 목록 로드
      final List<app_user.User> pendingUsers = [];
      for (final applicantId in currentMeeting.pendingApplicantIds) {
        final user = await UserService.getUser(applicantId);
        if (user != null) {
          pendingUsers.add(user);
        }
      }

      // 참여자 목록 로드
      final List<app_user.User> participantUsers = [];
      for (final participantId in currentMeeting.participantIds) {
        final user = await UserService.getUser(participantId);
        if (user != null) {
          participantUsers.add(user);
        }
      }

      // 호스트를 맨 앞으로 정렬
      participantUsers.sort((a, b) {
        if (a.id == currentMeeting.hostId) return -1;
        if (b.id == currentMeeting.hostId) return 1;
        return a.name.compareTo(b.name);
      });

      setState(() {
        _pendingApplicants = pendingUsers;
        _participants = participantUsers;
      });

      if (kDebugMode) {
        print('✅ 신청자 목록 로드 완료: ${_pendingApplicants.length}명 대기, ${_participants.length}명 참여');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 신청자 목록 로드 실패: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveApplicant(app_user.User applicant) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await MeetingService.approveMeetingApplication(widget.meeting.id, applicant.id);
      
      if (kDebugMode) {
        print('✅ 신청 승인 완료: ${applicant.name}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${applicant.name}님의 참여를 승인했습니다'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 목록 새로고침
      await _loadApplicantsAndParticipants();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 신청 승인 실패: $e');
      }

      String errorMessage = '승인에 실패했습니다';
      if (e.toString().contains('Meeting is full')) {
        errorMessage = '모임이 이미 찼습니다';
      } else if (e.toString().contains('User has not applied')) {
        errorMessage = '신청하지 않은 사용자입니다';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _rejectApplicant(app_user.User applicant) async {
    final confirmed = await CommonConfirmDialog.showDelete(
      context: context,
      title: '신청 거절',
      content: '${applicant.name}님의 참여 신청을 거절하시겠습니까?',
      confirmText: '거절',
    );

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await MeetingService.rejectMeetingApplication(widget.meeting.id, applicant.id);
      
      if (kDebugMode) {
        print('✅ 신청 거절 완료: ${applicant.name}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${applicant.name}님의 신청을 거절했습니다'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 목록 새로고침
      await _loadApplicantsAndParticipants();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 신청 거절 실패: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('거절에 실패했습니다'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text('신청자 관리', style: AppTextStyles.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true), // 변경사항이 있음을 알림
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPendingApplicants(),
                  _buildCurrentParticipants(),
                  const SizedBox(height: AppDesignTokens.spacing4),
                ],
              ),
            ),
    );
  }

  Widget _buildPendingApplicants() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing4,
        AppDesignTokens.spacing2,
        AppDesignTokens.spacing4,
        AppDesignTokens.spacing1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '승인 대기중',
                style: AppTextStyles.headlineMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing2,
                  vertical: AppDesignTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.1),
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Text(
                  '${_pendingApplicants.length}명',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppDesignTokens.primary,
                    fontWeight: AppDesignTokens.fontWeightBold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          if (_pendingApplicants.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignTokens.spacing5),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppDesignTokens.spacing2),
                    Text(
                      '대기중인 신청자가 없습니다',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingApplicants.length,
              itemBuilder: (context, index) {
                final applicant = _pendingApplicants[index];
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == _pendingApplicants.length - 1 ? 0 : AppDesignTokens.spacing3,
                  ),
                  child: _buildApplicantCard(applicant),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(app_user.User applicant) {
    return Container(
      padding: AppPadding.all16,
      decoration: BoxDecoration(
        color: AppDesignTokens.surfaceContainer.withOpacity(0.3),
        borderRadius: AppBorderRadius.medium,
        border: Border.all(
          color: AppDesignTokens.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
                backgroundImage: applicant.profileImageUrl != null && 
                               applicant.profileImageUrl!.isNotEmpty
                    ? NetworkImage(applicant.profileImageUrl!)
                    : null,
                child: applicant.profileImageUrl == null || 
                       applicant.profileImageUrl!.isEmpty
                    ? Text(
                        applicant.name[0],
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppDesignTokens.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppDesignTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicant.name,
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppDesignTokens.spacing1),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: AppDesignTokens.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          applicant.rating.toStringAsFixed(1),
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(width: AppDesignTokens.spacing2),
                        Text(
                          '가입 ${_getJoinDateText(applicant.createdAt)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    if (applicant.bio != null && applicant.bio!.isNotEmpty) ...[
                      const SizedBox(height: AppDesignTokens.spacing1),
                      Text(
                        applicant.bio!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        user: applicant,
                        isCurrentUser: false,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(60, 24),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                child: Text(
                  '프로필',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  text: '거절',
                  variant: ButtonVariant.outline,
                  onPressed: _isProcessing ? null : () => _rejectApplicant(applicant),
                  isLoading: _isProcessing,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Expanded(
                child: CommonButton(
                  text: '승인',
                  variant: ButtonVariant.primary,
                  onPressed: _isProcessing ? null : () => _approveApplicant(applicant),
                  isLoading: _isProcessing,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentParticipants() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.group,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '현재 참여자',
                style: AppTextStyles.headlineMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing2,
                  vertical: AppDesignTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceContainer,
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Text(
                  '${_participants.length}/${widget.meeting.maxParticipants}명',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: AppDesignTokens.fontWeightBold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          if (_participants.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignTokens.spacing5),
                child: Text(
                  '참여자가 없습니다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final participant = _participants[index];
                final isHost = participant.id == widget.meeting.hostId;
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == _participants.length - 1 ? 0 : AppDesignTokens.spacing3,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isHost 
                            ? AppDesignTokens.primary
                            : AppDesignTokens.surfaceContainer,
                        backgroundImage: participant.profileImageUrl != null && 
                                        participant.profileImageUrl!.isNotEmpty
                            ? NetworkImage(participant.profileImageUrl!)
                            : null,
                        child: participant.profileImageUrl == null || 
                               participant.profileImageUrl!.isEmpty
                            ? Text(
                                participant.name[0],
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isHost 
                                    ? Colors.white
                                    : AppDesignTokens.onSurface,
                                  fontWeight: AppDesignTokens.fontWeightBold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppDesignTokens.spacing3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  participant.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: isHost 
                                        ? AppDesignTokens.fontWeightSemiBold 
                                        : AppDesignTokens.fontWeightRegular,
                                  ),
                                ),
                                if (isHost) ...[
                                  const SizedBox(width: AppDesignTokens.spacing1),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppDesignTokens.spacing1, 
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppDesignTokens.primary,
                                      borderRadius: AppBorderRadius.small,
                                    ),
                                    child: Text(
                                      '호스트',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: AppDesignTokens.fontWeightBold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (participant.bio != null && participant.bio!.isNotEmpty)
                              Text(
                                participant.bio!,
                                style: AppTextStyles.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _getJoinDateText(DateTime joinDate) {
    final now = DateTime.now();
    final difference = now.difference(joinDate);

    if (difference.inDays < 30) {
      return '${difference.inDays}일째';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}개월째';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}년째';
    }
  }
}