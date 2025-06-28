import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting.dart';
import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/meeting_service.dart';
import '../../services/chat_service.dart';
import '../chat/chat_room_screen.dart';
import 'edit_meeting_screen.dart';
import 'participant_management_screen.dart';

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
        
        // 호스트 여부 판단
        _isHost = widget.meeting.hostId == _currentUserId;
        
        // 참여 여부 판단
        _isJoined = widget.meeting.participantIds.contains(_currentUserId);
        
        if (kDebugMode) {
          print('✅ 사용자 상태 확인:');
          print('  - 사용자: ${user.name}');
          print('  - 호스트 여부: $_isHost');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          foregroundColor: Theme.of(context).colorScheme.onBackground,
          elevation: 0,
          title: const Text('모임 상세'),
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
        final isCurrentlyHost = currentMeeting.hostId == _currentUserId;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.background,
            foregroundColor: Theme.of(context).colorScheme.onBackground,
            elevation: 0,
            title: const Text('모임 상세'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: 공유 기능
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('공유 기능 준비 중입니다'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
              Expanded(
                child: Text(
                  meeting.restaurantName ?? meeting.location,  // 식당 이름을 메인 타이틀로
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: meeting.status == 'completed'
                      ? Theme.of(context).colorScheme.outline.withOpacity(0.6)
                      : meeting.isAvailable 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  meeting.status == 'completed' 
                      ? '완료'
                      : meeting.isAvailable ? '모집중' : '마감',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          if (widget.meeting.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.meeting.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfo(Meeting meeting) {
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
        children: [
          _buildInfoRow(
            Icons.location_on,
            '장소',
            meeting.fullAddress ?? meeting.location,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.access_time,
            '시간',
            meeting.formattedDateTime,
          ),
          const SizedBox(height: 16),
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
          size: 20,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Meeting meeting) {
    return Container(
      width: double.infinity,
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
          Text(
            '모임 설명',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Text(
              meeting.description,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildParticipants(Meeting meeting) {
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
              Text(
                '참여자',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${meeting.currentParticipants}/${meeting.maxParticipants}명',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 실시간 참여자 리스트
          meeting.participantIds.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    '참여자가 없습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
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
                          margin: EdgeInsets.only(bottom: index == participants.length - 1 ? 0 : 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isHost 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surfaceContainer,
                                backgroundImage: participant.profileImageUrl != null && participant.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(participant.profileImageUrl!)
                                    : null,
                                child: participant.profileImageUrl == null || participant.profileImageUrl!.isEmpty
                                    ? Text(
                                        participant.name[0],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isHost 
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          participant.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: isHost ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                        if (isHost) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      ],
                                    ),
                                    if (participant.bio != null && participant.bio!.isNotEmpty)
                                      Text(
                                        participant.bio!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
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
                                      // TODO: 호스트 프로필 보기
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('프로필 보기 기능 준비 중입니다'),
                                          backgroundColor: Theme.of(context).colorScheme.primary,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
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
          child: OutlinedButton(
            onPressed: () {
              _showChatRoom();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              '채팅방',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _showMeetingManagement();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              '모임 관리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            child: OutlinedButton(
              onPressed: _isLoading ? null : () async {
                await _leaveMeeting();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                '참여 취소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _showChatRoom();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '채팅방 입장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (meeting.isAvailable && !_isLoading && _currentUserId != null)
              ? () async {
                  await _joinMeeting();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Theme.of(context).colorScheme.outline,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                meeting.isAvailable ? '모임 참여하기' : '모집 마감',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
        ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 헤더 (더 컴팩트하게)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  '모임 관리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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