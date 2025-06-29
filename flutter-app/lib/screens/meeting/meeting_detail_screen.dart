import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/meeting.dart';
import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/meeting_service.dart';
import '../../services/chat_service.dart';
import '../chat/chat_room_screen.dart';
import '../profile/user_profile_screen.dart';
import 'edit_meeting_screen.dart';
import 'participant_management_screen.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  bool _isJoined = false;
  bool _isHost = false;
  bool _isLoading = true;
  String? _currentUserId;
  app_user.User? _currentUser;
  app_user.User? _hostUser;
  List<app_user.User> _participants = [];
  bool _isLoadingParticipants = true;
  
  @override
  void initState() {
    super.initState();
    _initializeUserState();
  }
  
  Future<void> _initializeUserState() async {
    try {
      // 현재 로그인된 Firebase 사용자 확인
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser == null) {
        if (kDebugMode) {
          print('❌ 로그인되지 않은 사용자');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      _currentUserId = currentFirebaseUser.uid;
      
      // Firestore에서 사용자 정보 가져오기
      final user = await UserService.getUser(_currentUserId!);
      if (user != null) {
        _currentUser = user;
        
        // 호스트 여부 판단 (카카오 ID 기반 + Firebase UID 백업)
        bool isHostByKakaoId = false;
        if (widget.meeting.hostKakaoId != null && user.kakaoId != null) {
          isHostByKakaoId = widget.meeting.hostKakaoId == user.kakaoId;
        }
        bool isHostByFirebaseUid = widget.meeting.hostId == _currentUserId;
        
        _isHost = isHostByKakaoId || isHostByFirebaseUid;
        
        // 참여 여부 판단
        _isJoined = widget.meeting.participantIds.contains(_currentUserId);
        
        if (kDebugMode) {
          print('✅ 사용자 상태 확인:');
          print('  - 사용자: ${user.name}');
          print('  - 사용자 카카오 ID: ${user.kakaoId}');
          print('  - 모임 호스트 카카오 ID: ${widget.meeting.hostKakaoId}');
          print('  - 카카오 ID로 호스트 확인: $isHostByKakaoId');
          print('  - Firebase UID로 호스트 확인: $isHostByFirebaseUid');
          print('  - 최종 호스트 여부: $_isHost');
          print('  - 참여 여부: $_isJoined');
        }
        
        // 호스트 정보 가져오기
        if (widget.meeting.hostId != _currentUserId) {
          final hostUser = await UserService.getUser(widget.meeting.hostId);
          if (hostUser != null) {
            _hostUser = hostUser;
          }
        } else {
          _hostUser = user; // 현재 사용자가 호스트인 경우
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 상태 초기화 실패: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      // 참여자 목록 로드
      _loadParticipants();
    }
  }
  
  Future<void> _loadParticipants() async {
    if (widget.meeting.participantIds.isEmpty) {
      setState(() {
        _participants = [];
        _isLoadingParticipants = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingParticipants = true;
    });
    
    try {
      final List<app_user.User> participantUsers = [];
      
      for (final participantId in widget.meeting.participantIds) {
        final user = await UserService.getUser(participantId);
        if (user != null) {
          participantUsers.add(user);
        }
      }
      
      // 호스트를 맨 앞으로 정렬
      participantUsers.sort((a, b) {
        if (a.id == widget.meeting.hostId) return -1;
        if (b.id == widget.meeting.hostId) return 1;
        return 0;
      });
      
      setState(() {
        _participants = participantUsers;
      });
      
      if (kDebugMode) {
        print('✅ 참여자 목록 로드 완료: ${_participants.length}명');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 참여자 목록 로드 실패: $e');
      }
    } finally {
      setState(() {
        _isLoadingParticipants = false;
      });
    }
  }
  
  String _formatDate(DateTime dateTime) {
    final weekDays = ['일', '월', '화', '수', '목', '금', '토'];
    return '${dateTime.month}월 ${dateTime.day}일 (${weekDays[dateTime.weekday % 7]})';
  }
  
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }
  
  Future<void> _shareContent(Meeting meeting) async {
    try {
      // 공유할 텍스트 생성
      final shareText = StringBuffer();
      shareText.writeln('🍽️ [혼밥노노] 맛집 모임 초대');
      shareText.writeln();
      shareText.writeln('📍 ${meeting.restaurantName ?? meeting.location}');
      if (meeting.fullAddress != null) {
        shareText.writeln('   ${meeting.fullAddress}');
      }
      shareText.writeln();
      shareText.writeln('📅 ${_formatDate(meeting.dateTime)}');
      shareText.writeln('⏰ ${_formatTime(meeting.dateTime)}');
      shareText.writeln();
      shareText.writeln('👥 ${meeting.participantIds.length}/${meeting.maxParticipants}명 참여중');
      
      if (meeting.description.isNotEmpty) {
        shareText.writeln();
        shareText.writeln('💬 "${meeting.description}"');
      }
      
      shareText.writeln();
      shareText.writeln('함께 맛있는 식사하실 분들을 모집합니다!');
      
      // 카카오맵 링크 추가
      if (meeting.restaurantName != null && meeting.restaurantName!.isNotEmpty) {
        shareText.writeln();
        shareText.writeln('🗺️ 카카오맵에서 보기:');
        final encodedName = Uri.encodeComponent(meeting.restaurantName!);
        shareText.writeln('https://map.kakao.com/link/search/$encodedName');
      }
      
      shareText.writeln();
      shareText.writeln('📱 혼밥노노 앱에서 확인하세요');
      
      // 공유 실행
      await Share.share(
        shareText.toString(),
        subject: '혼밥노노 - ${meeting.restaurantName ?? meeting.location} 모임',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('모임 정보를 공유했습니다'),
            backgroundColor: AppDesignTokens.primary,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 공유 실패: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('공유 중 오류가 발생했습니다'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppDesignTokens.background,
          foregroundColor: AppDesignTokens.onSurface,
          elevation: 0,
          title: Text('모임 상세', style: AppTextStyles.titleLarge),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return StreamBuilder<List<Meeting>>(
      stream: MeetingService.getMeetingsStream(),
      builder: (context, meetingSnapshot) {
        // 현재 모임 정보 실시간 업데이트
        Meeting currentMeeting = widget.meeting;
        if (meetingSnapshot.hasData) {
          try {
            currentMeeting = meetingSnapshot.data!.firstWhere(
              (meeting) => meeting.id == widget.meeting.id,
            );
          } catch (e) {
            // 모임이 삭제된 경우 기본값 사용
            currentMeeting = widget.meeting;
          }
        }

        // 참여 상태 실시간 업데이트
        final isCurrentlyJoined = currentMeeting.participantIds.contains(_currentUserId);
        
        // 호스트 여부 실시간 업데이트 (카카오 ID 기반 + Firebase UID 백업)
        bool isCurrentlyHostByKakaoId = false;
        if (currentMeeting.hostKakaoId != null && _currentUser?.kakaoId != null) {
          isCurrentlyHostByKakaoId = currentMeeting.hostKakaoId == _currentUser!.kakaoId;
        }
        bool isCurrentlyHostByFirebaseUid = currentMeeting.hostId == _currentUserId;
        final isCurrentlyHost = isCurrentlyHostByKakaoId || isCurrentlyHostByFirebaseUid;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppDesignTokens.background,
            foregroundColor: AppDesignTokens.onSurface,
            elevation: 0,
            title: Text('모임 상세', style: AppTextStyles.titleLarge),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareContent(currentMeeting),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(currentMeeting),
                _buildInfo(currentMeeting),
                _buildDescription(currentMeeting),
                _buildParticipants(currentMeeting),
                const SizedBox(height: 80), // 버튼 공간 확보
              ],
            ),
          ),
          bottomNavigationBar: _buildJoinButton(currentMeeting, isCurrentlyJoined, isCurrentlyHost),
        );
      },
    );
  }

  Widget _buildHeader(Meeting meeting) {
    return CommonCard(
      padding: AppPadding.all20,
      margin: const EdgeInsets.fromLTRB(AppDesignTokens.spacing4, AppDesignTokens.spacing2, AppDesignTokens.spacing4, AppDesignTokens.spacing1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meeting.restaurantName ?? meeting.location,  // 식당 이름을 메인 타이틀로
                  style: AppTextStyles.headlineMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing3, vertical: AppDesignTokens.spacing1),
                decoration: BoxDecoration(
                  color: meeting.status == 'completed'
                      ? AppDesignTokens.outline.withOpacity(0.6)
                      : meeting.isAvailable 
                          ? AppDesignTokens.primary
                          : AppDesignTokens.outline,
                  borderRadius: AppBorderRadius.large,
                ),
                child: Text(
                  meeting.status == 'completed' 
                      ? '완료'
                      : meeting.isAvailable ? '모집중' : '마감',
                  style: AppTextStyles.labelSmall.white,
                ),
              ),
            ],
          ),
          
          if (widget.meeting.tags.isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.spacing4),
            Wrap(
              spacing: AppDesignTokens.spacing1,
              runSpacing: AppDesignTokens.spacing1,
              children: widget.meeting.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing2, vertical: AppDesignTokens.spacing1),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceContainer,
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Text(
                  tag,
                  style: AppTextStyles.labelSmall,
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfo(Meeting meeting) {
    return CommonCard(
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.location_on,
            '장소',
            meeting.fullAddress ?? meeting.location,
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          _buildInfoRow(
            Icons.access_time,
            '시간',
            meeting.formattedDateTime,
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          _buildInfoRow(
            Icons.group,
            '인원',
            '${meeting.currentParticipants}/${meeting.maxParticipants}명',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: AppDesignTokens.iconDefault,
          color: AppDesignTokens.outline,
        ),
        const SizedBox(width: AppDesignTokens.spacing3),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyLarge.semiBold,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Meeting meeting) {
    return CommonCard(
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '모임 설명',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          Container(
            width: double.infinity,
            padding: AppPadding.all16,
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceContainer.withOpacity(0.5),
              borderRadius: AppBorderRadius.small,
              border: Border.all(
                color: AppDesignTokens.outline.withOpacity(0.1),
              ),
            ),
            child: Text(
              meeting.description,
              style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildParticipants(Meeting meeting) {
    return CommonCard(
      padding: AppPadding.all20,
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '참여자',
                style: AppTextStyles.titleMedium.semiBold,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing2, vertical: AppDesignTokens.spacing1),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceContainer,
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Text(
                  '${meeting.currentParticipants}/${meeting.maxParticipants}명',
                  style: AppTextStyles.labelMedium.semiBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          // 실시간 참여자 리스트
          meeting.participantIds.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing5),
                  child: Text(
                    '참여자가 없습니다',
                    style: TextStyle(
                      fontSize: AppDesignTokens.fontSizeBodySmall,
                      color: AppDesignTokens.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : FutureBuilder<List<app_user.User>>(
                  future: _getParticipantUsers(meeting.participantIds),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDesignTokens.spacing5),
                          child: CircularProgressIndicator(
                            color: AppDesignTokens.primary,
                          ),
                        ),
                      );
                    }
                    
                    final participants = snapshot.data ?? [];
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final participant = participants[index];
                        final isHost = participant.id == meeting.hostId;
                        return Container(
                          margin: EdgeInsets.only(bottom: index == participants.length - 1 ? 0 : AppDesignTokens.spacing3),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: AppDesignTokens.spacing4,
                                backgroundColor: isHost 
                                    ? AppDesignTokens.primary
                                    : AppDesignTokens.surfaceContainer,
                                backgroundImage: participant.profileImageUrl != null && participant.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(participant.profileImageUrl!)
                                    : null,
                                child: participant.profileImageUrl == null || participant.profileImageUrl!.isEmpty
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
                                            fontWeight: isHost ? AppDesignTokens.fontWeightSemiBold : AppDesignTokens.fontWeightRegular,
                                          ),
                                        ),
                                        if (isHost) ...[
                                          const SizedBox(width: AppDesignTokens.spacing1),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: AppDesignTokens.spacing1, vertical: 2),
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
                              if (isHost)
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfileScreen(
                                            user: participant,
                                            isCurrentUser: participant.id == _currentUserId,
                                          ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(60, 24),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    ),
                                    child: Text(
                                      '프로필 보기',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }
  
  Future<List<app_user.User>> _getParticipantUsers(List<String> participantIds) async {
    final List<app_user.User> users = [];
    
    for (final participantId in participantIds) {
      final user = await UserService.getUser(participantId);
      if (user != null) {
        users.add(user);
      }
    }
    
    // 호스트를 맨 앞으로 정렬
    users.sort((a, b) {
      if (a.id == widget.meeting.hostId) return -1;
      if (b.id == widget.meeting.hostId) return 1;
      return a.name.compareTo(b.name);
    });
    
    return users;
  }

  Widget _buildJoinButton(Meeting meeting, bool isCurrentlyJoined, bool isCurrentlyHost) {
    return Container(
      padding: AppPadding.all16,
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: AppDesignTokens.elevationMedium,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: isCurrentlyHost ? _buildHostButtons() : _buildParticipantButton(meeting, isCurrentlyJoined),
      ),
    );
  }
  
  Widget _buildHostButtons() {
    return Row(
      children: [
        Expanded(
          child: CommonButton(
            text: '채팅방',
            variant: ButtonVariant.outline,
            onPressed: _showChatRoom,
            fullWidth: true,
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing3),
        Expanded(
          child: CommonButton(
            text: '모임 관리',
            variant: ButtonVariant.primary,
            onPressed: _showMeetingManagement,
            fullWidth: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildParticipantButton(Meeting meeting, bool isCurrentlyJoined) {
    if (isCurrentlyJoined) {
      return Row(
        children: [
          Expanded(
            child: CommonButton(
              text: '참여 취소',
              variant: ButtonVariant.outline,
              onPressed: _isLoading ? null : () async {
                await _leaveMeeting();
              },
              isLoading: _isLoading,
              fullWidth: true,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing3),
          Expanded(
            child: CommonButton(
              text: '채팅방 입장',
              variant: ButtonVariant.primary,
              onPressed: _showChatRoom,
              fullWidth: true,
            ),
          ),
        ],
      );
    } else {
      return CommonButton(
        text: meeting.isAvailable ? '모임 참여하기' : '모집 마감',
        variant: ButtonVariant.primary,
        onPressed: (meeting.isAvailable && !_isLoading && _currentUserId != null)
            ? () async {
                await _joinMeeting();
              }
            : null,
        isLoading: _isLoading,
        fullWidth: true,
      );
    }
  }
  
  void _showChatRoom() {
    if (_currentUserId == null) {
      _showErrorMessage('로그인이 필요합니다');
      return;
    }
    
    // 참여자만 채팅방 입장 가능
    if (!_isJoined && !_isHost) {
      _showErrorMessage('모임에 참여해야 채팅방에 입장할 수 있습니다');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(meeting: widget.meeting),
      ),
    );
  }
  
  void _showMeetingManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMeetingManagementModal(),
    );
  }
  
  Widget _buildMeetingManagementModal() {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignTokens.radiusLarge)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: AppDesignTokens.spacing3),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppDesignTokens.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 헤더 (더 컴팩트하게)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDesignTokens.spacing5, AppDesignTokens.spacing4, AppDesignTokens.spacing3, AppDesignTokens.spacing3),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: AppDesignTokens.primary,
                  size: 22,
                ),
                const SizedBox(width: AppDesignTokens.spacing2),
                Text(
                  '모임 관리',
                  style: AppTextStyles.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 22),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          
          // 4개 관리 메뉴 (1줄에 4개 배치, 구분선 제거)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 모임 수정
                Expanded(
                  child: _buildCompactManagementOption(
                    icon: Icons.edit,
                    title: '모임 수정',
                    onTap: () {
                      Navigator.pop(context);
                      _editMeeting();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                
                // 참여자 관리
                Expanded(
                  child: _buildCompactManagementOption(
                    icon: Icons.people,
                    title: '참여자 관리',
                    onTap: () {
                      Navigator.pop(context);
                      _manageParticipants();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                
                // 모임 완료
                Expanded(
                  child: _buildCompactManagementOption(
                    icon: Icons.check_circle_outline,
                    title: '모임 완료',
                    onTap: () {
                      Navigator.pop(context);
                      _completeMeeting();
                    },
                    isSpecial: true,
                  ),
                ),
                const SizedBox(width: 8),
                
                // 모임 삭제
                Expanded(
                  child: _buildCompactManagementOption(
                    icon: Icons.delete_outline,
                    title: '모임 삭제',
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMeeting();
                    },
                    isDestructive: true,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _buildCompactManagementOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isSpecial = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDestructive 
                      ? Colors.red.withOpacity(0.1)
                      : isSpecial
                          ? Colors.green.withOpacity(0.1)
                          : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive 
                      ? Colors.red
                      : isSpecial
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDestructive 
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _editMeeting() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMeetingScreen(meeting: widget.meeting),
      ),
    );
    
    // 수정이 완료되면 화면 새로고침
    if (result == true) {
      _initializeUserState();
    }
  }
  
  Future<void> _manageParticipants() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParticipantManagementScreen(meeting: widget.meeting),
      ),
    );
    
    // 참여자 관리 후 화면 새로고침 (즉시 반영)
    if (result == true) {
      await _initializeUserState();
      await _loadParticipants();
    }
  }
  
  Future<void> _completeMeeting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 완료'),
        content: const Text('모임을 완료하시겠습니까?\n완료된 모임의 채팅방은 읽기 전용이 됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
            child: const Text('완료'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      await MeetingService.completeMeeting(widget.meeting.id);
      
      // 모임 완료 시스템 메시지 전송
      await ChatService.sendSystemMessage(
        meetingId: widget.meeting.id,
        content: '모임이 완료되었습니다. 수고하셨습니다! 🎉',
      );

      if (kDebugMode) {
        print('✅ 모임 완료 성공: ${widget.meeting.id}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모임이 완료되었습니다'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 화면 새로고침
        _initializeUserState();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 완료 실패: $e');
      }
      
      if (mounted) {
        _showErrorMessage('모임 완료에 실패했습니다');
      }
    }
  }
  
  void _deleteMeeting() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 삭제'),
        content: const Text('정말로 모임을 삭제하시겠습니까?\n삭제된 모임은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 닫기
              await _performDeleteMeeting();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performDeleteMeeting() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 모임과 관련된 모든 메시지 삭제
      await ChatService.deleteAllMessages(widget.meeting.id);
      
      // 모임 삭제
      await MeetingService.deleteMeeting(widget.meeting.id);
      
      if (kDebugMode) {
        print('✅ 모임 삭제 성공: ${widget.meeting.id}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모임이 삭제되었습니다'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 홈 화면으로 돌아가기
        Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 삭제 실패: $e');
      }
      
      if (mounted) {
        _showErrorMessage('모임 삭제에 실패했습니다');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _joinMeeting() async {
    if (_currentUserId == null) {
      _showErrorMessage('로그인이 필요합니다');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await MeetingService.joinMeeting(widget.meeting.id, _currentUserId!);
      
      setState(() {
        _isJoined = true;
      });
      
      // 참여자 목록 재로드
      _loadParticipants();
      
      // 입장 시스템 메시지 전송
      await ChatService.sendSystemMessage(
        meetingId: widget.meeting.id,
        content: '${_currentUser?.name ?? '사용자'}님이 모임에 참여했습니다.',
      );
      
      if (kDebugMode) {
        print('✅ 모임 참여 성공: ${widget.meeting.id}');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('모임에 참여했습니다! 호스트와 함께 식사를 즐겨보세요.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 참여 실패: $e');
      }
      
      String errorMessage = '모임 참여에 실패했습니다';
      if (e.toString().contains('Already joined')) {
        errorMessage = '이미 참여한 모임입니다';
      } else if (e.toString().contains('Meeting is full')) {
        errorMessage = '모임이 막 찬습니다';
      }
      
      _showErrorMessage(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _leaveMeeting() async {
    if (_currentUserId == null) {
      _showErrorMessage('로그인이 필요합니다');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await MeetingService.leaveMeeting(widget.meeting.id, _currentUserId!);
      
      setState(() {
        _isJoined = false;
      });
      
      // 참여자 목록 재로드
      _loadParticipants();
      
      // 퇴장 시스템 메시지 전송
      await ChatService.sendSystemMessage(
        meetingId: widget.meeting.id,
        content: '${_currentUser?.name ?? '사용자'}님이 모임에서 나갔습니다.',
      );
      
      if (kDebugMode) {
        print('✅ 모임 탈퇴 성공: ${widget.meeting.id}');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('모임 참여를 취소했습니다'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 탈퇴 실패: $e');
      }
      
      String errorMessage = '모임 탈퇴에 실패했습니다';
      if (e.toString().contains('Not a participant')) {
        errorMessage = '이미 참여하지 않은 모임입니다';
      } else if (e.toString().contains('Meeting not found')) {
        errorMessage = '모임을 찾을 수 없습니다';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = '권한이 없습니다. 다시 로그인해주세요';
      }
      
      _showErrorMessage(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}