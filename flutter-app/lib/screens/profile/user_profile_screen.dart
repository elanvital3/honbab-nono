import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user.dart' as app_user;
import '../../models/meeting.dart';
import '../../services/meeting_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/user_badge_chip.dart';
import 'badge_selection_screen.dart';
import '../evaluation/user_evaluation_screen.dart';

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
  bool _showCompletedMeetings = false; // 완료된 모임 표시 여부

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
            _buildBadgeSection(),
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
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '활동 통계',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: AppDesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          StreamBuilder<List<Meeting>>(
            stream: MeetingService.getUserMeetingsStream(widget.user.id),
            builder: (context, snapshot) {
              // 실제 모임 데이터로 통계 계산
              int participatedCount = 0;
              int hostedCount = 0;
              double averageRating = widget.user.rating;
              
              if (snapshot.hasData) {
                final meetings = snapshot.data!;
                participatedCount = meetings.length;
                hostedCount = meetings.where((m) => m.hostId == widget.user.id).length;
              }
              
              return Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '참여한 모임',
                      '${participatedCount}회',
                      Icons.group,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '주최한 모임',
                      '${hostedCount}회',
                      Icons.star,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '평균 별점',
                      '${averageRating.toStringAsFixed(1)}점',
                      Icons.favorite,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppDesignTokens.primary,
          size: 24,
        ),
        const SizedBox(height: AppDesignTokens.spacing2),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: AppDesignTokens.fontWeightBold,
            color: AppDesignTokens.primary,
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing1),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
          textAlign: TextAlign.center,
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
    // 현재 시간
    final now = DateTime.now();
    
    // 필터링된 모임 목록
    final filteredMeetings = _hostedMeetings.where((meeting) {
      if (_showCompletedMeetings) {
        return true; // 모든 모임 표시
      } else {
        // 진행중인 모임만 표시 (미래 모임 + 완료되지 않은 모임)
        return meeting.status != 'completed' || meeting.dateTime.isAfter(now);
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing4,
            AppDesignTokens.spacing3,
            AppDesignTokens.spacing4,
            AppDesignTokens.spacing1,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주최한 모임',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
              // 필터 토글
              Row(
                children: [
                  Icon(
                    _showCompletedMeetings ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                    color: AppDesignTokens.outline,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showCompletedMeetings = !_showCompletedMeetings;
                      });
                    },
                    child: Text(
                      _showCompletedMeetings ? '완료된 모임 숨기기' : '완료된 모임 보기',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing1),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDesignTokens.spacing4),
              child: CircularProgressIndicator(),
            ),
          )
        else if (filteredMeetings.isEmpty)
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
                    _hostedMeetings.isEmpty 
                        ? '주최한 모임이 없습니다'
                        : _showCompletedMeetings 
                            ? '주최한 모임이 없습니다'
                            : '진행중인 모임이 없습니다',
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
            itemCount: filteredMeetings.length > 3 ? 3 : filteredMeetings.length,
            itemBuilder: (context, index) {
              final meeting = filteredMeetings[index];
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatDate(meeting.dateTime)} · ${meeting.participantIds.length}/${meeting.maxParticipants}명',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        // 완료된 모임에만 평가 버튼 표시
                        if (meeting.status == 'completed' && widget.isCurrentUser)
                          GestureDetector(
                            onTap: () => _navigateToEvaluation(meeting),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppDesignTokens.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppDesignTokens.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '평가',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppDesignTokens.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        
        // 전체보기 버튼 (3개보다 많은 모임이 있을 때만 표시)
        if (filteredMeetings.length > 3)
          Padding(
            padding: AppPadding.horizontal16.add(AppPadding.vertical8),
            child: Center(
              child: TextButton(
                onPressed: () => _showAllMeetings(filteredMeetings),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '전체보기 (${filteredMeetings.length}개)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppDesignTokens.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBadgeSection() {
    return CommonCard(
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '특성 뱃지',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
              if (widget.isCurrentUser)
                GestureDetector(
                  onTap: _editBadges,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit,
                          color: AppDesignTokens.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '편집',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppDesignTokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          if (widget.user.badges.isNotEmpty)
            UserBadgesList(badgeIds: widget.user.badges)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.star_border,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isCurrentUser
                        ? '아직 특성 뱃지를 설정하지 않았어요\n편집 버튼을 눌러서 설정해보세요!'
                        : '설정된 특성 뱃지가 없습니다',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _editBadges() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => BadgeSelectionScreen(
          initialBadges: widget.user.badges,
          isOnboarding: false,
        ),
      ),
    );

    if (result != null && mounted) {
      // 프로필 화면 새로고침 (부모 위젯에서 상태 업데이트 필요)
      setState(() {
        // 로컬 상태는 부모에서 관리되므로 여기서는 UI만 새로고침
      });
    }
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

  void _navigateToEvaluation(Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserEvaluationScreen(
          meetingId: meeting.id,
          meeting: meeting,
        ),
      ),
    );
  }

  void _showAllMeetings(List<Meeting> meetings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 헤더
            Padding(
              padding: AppPadding.horizontal16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '주최한 모임 전체',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // 모임 리스트
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: AppPadding.all16,
                itemCount: meetings.length,
                itemBuilder: (context, index) {
                  final meeting = meetings[index];
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
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignTokens.spacing2),
                        Text(
                          meeting.description,
                          style: AppTextStyles.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppDesignTokens.spacing2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppDesignTokens.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(meeting.dateTime),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppDesignTokens.outline,
                              ),
                            ),
                            const SizedBox(width: AppDesignTokens.spacing3),
                            Icon(
                              Icons.people,
                              size: 16,
                              color: AppDesignTokens.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${meeting.participantIds.length}/${meeting.maxParticipants}명',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppDesignTokens.outline,
                              ),
                            ),
                          ],
                        ),
                        
                        // 평가 버튼 (완료된 모임만)
                        if (meeting.status == 'completed') ...[
                          const SizedBox(height: AppDesignTokens.spacing2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // 모달 닫기
                                  _navigateToEvaluation(meeting);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppDesignTokens.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppDesignTokens.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: AppDesignTokens.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '평가',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppDesignTokens.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}