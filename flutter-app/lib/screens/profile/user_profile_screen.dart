import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user.dart' as app_user;
import '../../models/meeting.dart';
import '../../services/meeting_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';

class UserProfileScreen extends StatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.isCurrentUser = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  List<Meeting> _hostedMeetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserMeetings();
  }

  Future<void> _loadUserMeetings() async {
    try {
      if (kDebugMode) {
        print('🔍 사용자 모임 로드 시작');
        print('  - 사용자 ID: ${widget.user.id}');
        print('  - 사용자 이름: ${widget.user.name}');
      }
      
      // 사용자가 호스트인 모임들 가져오기
      final meetings = await MeetingService.getMeetingsByHost(widget.user.id);
      
      if (kDebugMode) {
        print('📊 로드된 모임 수: ${meetings.length}');
        if (meetings.isNotEmpty) {
          for (final meeting in meetings) {
            print('  - 모임: ${meeting.restaurantName ?? meeting.location}');
            print('    호스트 ID: ${meeting.hostId}');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _hostedMeetings = meetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 모임 로드 실패: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text(
          widget.isCurrentUser ? '내 프로필' : '프로필',
          style: AppTextStyles.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            _buildStats(),
            _buildRatings(),
            _buildHostedMeetings(),
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing4,
        AppDesignTokens.spacing2,
        AppDesignTokens.spacing4,
        AppDesignTokens.spacing1,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
            backgroundImage: widget.user.profileImageUrl != null && 
                            widget.user.profileImageUrl!.isNotEmpty
                ? NetworkImage(widget.user.profileImageUrl!)
                : null,
            child: widget.user.profileImageUrl == null || 
                   widget.user.profileImageUrl!.isEmpty
                ? Text(
                    widget.user.name[0],
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppDesignTokens.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDesignTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: AppDesignTokens.spacing1),
                Text(
                  _getJoinDateText(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing2),
                  Text(
                    widget.user.bio!,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return CommonCard(
      padding: AppPadding.all16,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: StreamBuilder<List<Meeting>>(
        stream: MeetingService.getUserMeetingsStream(widget.user.id),
        builder: (context, snapshot) {
          // 실제 모임 데이터로 통계 계산
          int completedCount = 0;
          int activeCount = 0;
          int hostedCount = 0;
          
          if (snapshot.hasData) {
            final meetings = snapshot.data!;
            for (final meeting in meetings) {
              // 참여한 모임 분류
              if (meeting.status == 'completed') {
                completedCount++;
              } else {
                activeCount++;
              }
              
              // 주최한 모임 카운트
              if (meeting.hostId == widget.user.id) {
                hostedCount++;
              }
            }
          }
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '완료된 모임',
                completedCount.toString(),
                Icons.check_circle,
              ),
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              _buildStatItem(
                '진행중인 모임',
                activeCount.toString(),
                Icons.schedule,
              ),
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              _buildStatItem(
                '주최한 모임',
                hostedCount.toString(),
                Icons.flag,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppDesignTokens.primary,
          size: 20,
        ),
        const SizedBox(height: AppDesignTokens.spacing1),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: AppDesignTokens.fontWeightBold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildRatings() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '받은 평가',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          _buildRatingItem('⏰ 시간 준수', widget.user.rating),
          const SizedBox(height: AppDesignTokens.spacing2),
          _buildRatingItem('💬 대화 매너', widget.user.rating),
          const SizedBox(height: AppDesignTokens.spacing2),
          _buildRatingItem('🤝 재만남 의향', widget.user.rating),
        ],
      ),
    );
  }

  Widget _buildRatingItem(String label, double rating) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: AppDesignTokens.primary,
              size: 16,
            );
          }),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        Text(
          rating.toStringAsFixed(1),
          style: AppTextStyles.labelMedium.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildHostedMeetings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing4,
            AppDesignTokens.spacing3,
            AppDesignTokens.spacing4,
            AppDesignTokens.spacing2,
          ),
          child: Text(
            '주최한 모임',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
        ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDesignTokens.spacing4),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_hostedMeetings.isEmpty)
          CommonCard(
            padding: AppPadding.all20,
            margin: AppPadding.horizontal16,
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing2),
                  Text(
                    '주최한 모임이 없습니다',
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
            padding: AppPadding.horizontal16,
            itemCount: _hostedMeetings.length > 3 ? 3 : _hostedMeetings.length,
            itemBuilder: (context, index) {
              final meeting = _hostedMeetings[index];
              return CommonCard(
                margin: EdgeInsets.only(bottom: AppDesignTokens.spacing2),
                padding: AppPadding.all16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.restaurantName ?? meeting.location,
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesignTokens.spacing2,
                            vertical: AppDesignTokens.spacing1,
                          ),
                          decoration: BoxDecoration(
                            color: meeting.status == 'completed'
                                ? AppDesignTokens.outline.withOpacity(0.6)
                                : meeting.isAvailable
                                    ? AppDesignTokens.primary
                                    : AppDesignTokens.outline,
                            borderRadius: AppBorderRadius.medium,
                          ),
                          child: Text(
                            meeting.status == 'completed'
                                ? '완료'
                                : meeting.isAvailable
                                    ? '모집중'
                                    : '마감',
                            style: AppTextStyles.labelSmall.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDesignTokens.spacing1),
                    Text(
                      '${_formatDate(meeting.dateTime)} · ${meeting.participantIds.length}/${meeting.maxParticipants}명',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _getJoinDateText() {
    final joinDate = widget.user.createdAt;
    final now = DateTime.now();
    final difference = now.difference(joinDate);

    if (difference.inDays < 30) {
      return '가입한 지 ${difference.inDays}일째';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '가입한 지 ${months}개월째';
    } else {
      final years = (difference.inDays / 365).floor();
      return '가입한 지 ${years}년째';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}';
  }
}