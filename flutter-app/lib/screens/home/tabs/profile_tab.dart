import 'package:flutter/material.dart';
import '../../../models/meeting.dart';
import '../../../models/user.dart';
import '../../../services/meeting_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/evaluation_service.dart';
import '../../../services/user_service.dart';
import '../../profile/user_comments_screen.dart';
import '../../../styles/text_styles.dart';
import '../../../constants/app_design_tokens.dart';
import '../../profile/profile_edit_screen.dart';
import '../../settings/notification_settings_screen.dart';
import '../../settings/account_deletion_screen.dart';
import '../../../components/user_badge_chip.dart';
import '../../profile/my_meetings_history_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab>
    with AutomaticKeepAliveClientMixin {
  String? _currentUserId;
  User? _currentUser;
  List<Meeting> _myMeetings = [];
  List<Meeting> _upcomingMeetings = [];
  List<Meeting> _completedMeetings = [];
  bool _isLoading = true;
  int _participatedMeetings = 0;
  int _hostedMeetings = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUserId = currentFirebaseUser.uid;

      // 사용자 정보와 모임 데이터 병렬로 로드
      final results = await Future.wait<dynamic>([
        UserService.getUser(_currentUserId!),
        MeetingService.getMeetingsStream().first,
      ]);

      final user = results[0] as User?;
      final allMeetings = results[1] as List<Meeting>;

      if (user != null && mounted) {
        // 내가 참여한 모임들 필터링
        final myMeetings =
            allMeetings.where((meeting) {
              return meeting.participantIds.contains(_currentUserId) ||
                  meeting.hostId == _currentUserId;
            }).toList();

        // 통계 계산
        _participatedMeetings = myMeetings.length;
        _hostedMeetings =
            myMeetings.where((m) => m.hostId == _currentUserId).length;

        // 예정/완료 모임 분류 - status 기준으로 변경
        _upcomingMeetings =
            myMeetings.where((m) => m.status != 'completed').toList();
        _completedMeetings =
            myMeetings.where((m) => m.status == 'completed').toList();

        setState(() {
          _currentUser = user;
          _myMeetings = myMeetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 사용자 데이터 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      return _buildLoginPrompt();
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          // 프로필 헤더
          _buildProfileHeader(),

          // 통계 정보
          _buildStatsSection(),

          // 받은 평가 (기본값)
          _buildRatingsSection(),

          // 받은 코멘트
          _buildCommentsSection(),

          // 내 모임 히스토리
          _buildMyMeetingsSection(),

          // 설정 메뉴
          _buildSettingsSection(),

          // 문의 섹션 (별도 카드)
          _buildInquirySection(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '로그인이 필요합니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '프로필을 보려면 로그인해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 프로필 사진과 이름
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
                backgroundImage:
                    _currentUser!.profileImageUrl != null
                        ? NetworkImage(_currentUser!.profileImageUrl!)
                        : null,
                child:
                    _currentUser!.profileImageUrl == null
                        ? Text(
                          _currentUser!.name.isNotEmpty
                              ? _currentUser!.name[0]
                              : '?',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppDesignTokens.primary,
                          ),
                        )
                        : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser!.name,
                      style: AppTextStyles.headlineMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showProfileEdit(),
                icon: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),

          // 사용자의 실제 뱃지 표시
          if (_currentUser!.badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: UserBadgesList(badgeIds: _currentUser!.badges),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('활동 통계', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '참여한 모임',
                  '${_participatedMeetings}회',
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
                  '${_hostedMeetings}회',
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
                  '${_currentUser!.rating.toStringAsFixed(1)}점',
                  Icons.favorite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRatingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('받은 평가', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),

          _buildRatingItem('⏰ 시간 준수', _currentUser!.rating),
          const SizedBox(height: 12),
          _buildRatingItem('💬 대화 매너', _currentUser!.rating),
          const SizedBox(height: 12),
          _buildRatingItem('🤝 재만남 의향', _currentUser!.rating),
        ],
      ),
    );
  }

  Widget _buildRatingItem(String label, double rating) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              );
            }),
          ),
        ),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16, // 14에서 16으로 증가 (평점 숫자 크기 개선)
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('받은 코멘트', style: AppTextStyles.titleLarge),
              GestureDetector(
                onTap: () => _navigateToCommentsDetail(_currentUserId!),
                child: Text(
                  '전체보기',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: EvaluationService.getUserComments(_currentUserId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Text(
                  '코멘트를 불러올 수 없습니다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                );
              }
              
              final comments = snapshot.data ?? [];
              
              if (comments.isEmpty) {
                return Text(
                  '아직 받은 코멘트가 없습니다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[600],
                  ),
                );
              }
              
              // 최근 3개 코멘트만 표시
              final recentComments = comments.take(3).toList();
              
              return Column(
                children: recentComments.map((comment) => _buildCommentItem(comment)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final DateTime? meetingDate = comment['meetingDateTime'] as DateTime?;
    final String meetingLocation = comment['meetingLocation'] as String? ?? '알 수 없는 장소';
    final String? restaurantName = comment['meetingRestaurant'] as String?;
    final String commentText = comment['comment'] as String;
    final double rating = comment['averageRating'] as double? ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모임 정보
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  restaurantName ?? meetingLocation,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (meetingDate != null) ...[
                Text(
                  '${meetingDate.month}/${meetingDate.day}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          
          // 코멘트 내용
          Text(
            commentText,
            style: AppTextStyles.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          // 평점
          if (rating > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  );
                }),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToCommentsDetail(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserCommentsScreen(userId: userId),
      ),
    );
  }

  Widget _buildMyMeetingsSection() {
    if (_myMeetings.isEmpty) {
      return _buildEmptyMeetingsSection();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('내 모임', style: AppTextStyles.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () => _showAllMeetings(),
                child: Text(
                  '전체보기',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 예정된 모임
          if (_upcomingMeetings.isNotEmpty) ...[
            Text(
              '예정된 모임 (${_upcomingMeetings.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ..._upcomingMeetings
                .take(2)
                .map((meeting) => _buildMeetingItem(meeting)),
            const SizedBox(height: 16),
          ],

          // 완료된 모임
          if (_completedMeetings.isNotEmpty) ...[
            Text(
              '완료된 모임 (${_completedMeetings.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ..._completedMeetings
                .take(2)
                .map((meeting) => _buildMeetingItem(meeting)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMeetingsSection() {
    return Container(
      width: double.infinity, // 가로 꽉 차도록 설정
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 60,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '참여한 모임이 없어요',
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 모임에 참여해보세요!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingItem(Meeting meeting) {
    final isHost = meeting.hostId == _currentUserId;
    final isUpcoming = meeting.status != 'completed';  // status 기준으로 변경

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('🔥 ProfileTab: 모임 아이템 클릭됨 - ${meeting.id}');
        Navigator.pushNamed(
          context,
          '/meeting-detail',
          arguments: meeting,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  isHost
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant,
              color:
                  isHost ? Colors.white : Theme.of(context).colorScheme.outline,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meeting.restaurantName ?? meeting.location,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '호스트',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    Text(
                      _formatMeetingDate(meeting.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isUpcoming
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.2)
                                : Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUpcoming ? '예정' : '완료',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isUpcoming
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('설정', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),

          _buildSettingItem(
            Icons.notifications,
            '알림 설정',
            '푸시 알림 및 소리 설정',
            () => _showNotificationSettings(),
          ),
          // 본인인증 상태
          _buildVerificationStatus(),
          const SizedBox(height: 8),
          
          _buildSettingItem(
            Icons.delete_forever,
            '회원탈퇴',
            '모든 데이터가 삭제됩니다',
            () => _showDeleteAccountDialog(),
            isLogout: true,
          ),
          
          // 사업자 정보 섹션 (우선 숨김)
          // TODO: 나중에 필요할 때 다시 활성화
          /*
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사업자 정보',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 법인명
                _buildBusinessInfoRow('법인명', '구구랩'),
                const SizedBox(height: 8),
                
                // 대표자명
                _buildBusinessInfoRow('대표자명', '김태훈'),
                const SizedBox(height: 8),
                
                // 사업자등록번호
                _buildBusinessInfoRow('사업자등록번호', '418-26-01909'),
                const SizedBox(height: 8),
                
                // 주소
                _buildBusinessInfoRow('주소', '충청남도 천안시 서북구 불당26로 80, 405동 2401호'),
                const SizedBox(height: 8),
                
                // 고객센터
                _buildBusinessInfoRow('고객센터', '070-8028-1701'),
                const SizedBox(height: 12),
                
                const Divider(color: Color(0xFFE0E0E0), height: 1),
                const SizedBox(height: 12),
                
                Text(
                  '업종: 정보통신업, 컴퓨터 프로그래밍 서비스업',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          */
        ],
      ),
    );
  }

  Widget _buildInquirySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('문의', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Icon(
                Icons.email,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Text(
                'honbabnono@gmail.com',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color:
                    isLogout
                        ? Colors.red[400]
                        : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            isLogout
                                ? Colors.red[400]
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLogout)
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }


  String _formatMeetingDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return '오늘';
    } else if (difference == 1) {
      return '내일';
    } else if (difference > 0) {
      return '${date.month}/${date.day}';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  void _showProfileEdit() async {
    if (_currentUser == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(user: _currentUser!),
      ),
    );

    // 프로필이 업데이트된 경우 새로고침
    if (result == true) {
      _loadUserData();
    }
  }

  void _showAllMeetings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyMeetingsHistoryScreen(),
      ),
    );
  }

  void _showNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  /*
  void _showCustomerService() async {
    const email = 'elanvital3@gmail.com';
    const subject = '혼밥노노 앱 문의';
    const body = '''
안녕하세요, 혼밥노노 앱을 이용해주셔서 감사합니다.

문의 내용:
[여기에 문의 내용을 작성해주세요]

---
앱 버전: 1.0.0
''';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이메일 앱을 열 수 없습니다. elanvital3@gmail.com으로 직접 연락해주세요.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
          ),
        );
      }
    }
  }

  void _showLogoutDialog() async {
    final confirmed = await CommonConfirmDialog.show(
      context: context,
      title: '로그아웃',
      content: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
      cancelText: '취소',
    );
    
    if (confirmed) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _showDeleteAccountDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountDeletionScreen(),
      ),
    );
  }

  void _showAdultVerification() {
    if (_currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExistingUserAdultVerificationScreen(
          userId: _currentUser!.id,
          userName: _currentUser!.name,
        ),
      ),
    ).then((_) {
      // 성인인증 완료 후 사용자 정보 새로고침
      _loadUserData();
    });
  }
  
  Widget _buildVerificationStatus() {
    final isVerified = _currentUser?.isAdultVerified ?? false;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isVerified ? null : _showAdultVerification,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                isVerified ? Icons.verified_user : Icons.warning,
                size: 24,
                color: isVerified 
                    ? AppDesignTokens.primary 
                    : Colors.orange[400],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '본인인증',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isVerified) ...[
                      const SizedBox(height: 2),
                      Text(
                        '모임 참여를 위해 본인인증이 필요합니다',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.orange[600],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        '인증 완료',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppDesignTokens.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isVerified) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '인증하기',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: AppDesignTokens.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _joinMeeting(Meeting meeting) async {
    final currentUserId = AuthService.currentUserId;
    if (currentUserId == null) {
      _showErrorSnackBar('로그인이 필요합니다');
      return;
    }

    try {
      // 현재 사용자 정보 가져오기
      final currentUser = await UserService.getUser(currentUserId);
      if (currentUser == null) {
        _showErrorSnackBar('사용자 정보를 찾을 수 없습니다');
        return;
      }

      // 본인인증 필수 체크
      if (!currentUser.isAdultVerified) {
        _showJoinVerificationRequiredDialog();
        return;
      }

      // 모임 참석 로직 (기존 구현)
      await MeetingService.joinMeeting(meeting.id, currentUserId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${meeting.restaurantName ?? meeting.location} 모임에 참석했습니다!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('모임 참석 중 오류가 발생했습니다: $e');
      }
    }
  }

  void _showJoinVerificationRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.verified_user,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('본인인증이 필요합니다'),
          ],
        ),
        content: const Text(
          '모임에 참석하려면 본인인증을 완료해야 합니다.\n마이페이지에서 본인인증을 진행해주세요.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '확인',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildVerificationStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.verified_user,
            color: AppDesignTokens.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '본인인증',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '안전한 만남을 위해 인증이 완료되었습니다',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppDesignTokens.primary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: AppDesignTokens.primary,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountDeletionScreen(),
      ),
    );
  }

  Widget _buildBusinessInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppDesignTokens.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}