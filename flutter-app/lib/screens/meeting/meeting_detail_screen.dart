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
import 'applicant_management_screen.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';
import '../../components/common/common_confirm_dialog.dart';
import '../../components/dutch_pay_calculator.dart';
import '../../components/meeting_auto_complete_dialog.dart';
import '../../services/meeting_auto_completion_service.dart';
import '../evaluation/user_evaluation_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isJoined = false;
  bool _isHost = false;
  bool _isPending = false; // 승인 대기 상태
  bool _isLoading = true;
  String? _currentUserId;
  app_user.User? _currentUser;
  app_user.User? _hostUser;
  List<app_user.User> _participants = [];
  List<app_user.User> _pendingApplicants = []; // 승인 대기자 목록
  bool _isLoadingParticipants = true;
  Meeting? _currentMeeting; // 현재 모임 데이터 (실시간 업데이트용)
  
  // 탭 컨트롤러 추가
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMeeting = widget.meeting; // 초기 데이터 설정
    _tabController = TabController(length: 2, vsync: this);
    
    // 탭 변경 시 화면 새로고침 (높이 재계산)
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          // 탭 변경 시 화면 새로고침
        });
      }
    });
    
    _initializeUserState();
    
    // 자동 완료 체크 (호스트만)
    _checkAutoCompletion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 앱이 다시 포어그라운드로 돌아올 때 모임 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('🔄 앱 포어그라운드 복귀 - 모임 데이터 새로고침');
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        _refreshMeetingData();
      });
    }
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
        
        // 호스트 여부 판단 (UID만 사용)
        _isHost = _currentMeeting!.hostId == _currentUserId;
        
        // 참여 여부 및 신청 상태 판단
        _isJoined = _currentMeeting!.participantIds.contains(_currentUserId);
        _isPending = _currentMeeting!.pendingApplicantIds.contains(_currentUserId);
        
        if (kDebugMode) {
          print('✅ 사용자 상태 확인:');
          print('  - 사용자: ${user.name}');
          print('  - 호스트 여부: $_isHost');
          print('  - 참여 여부: $_isJoined');
        }
        
        // 호스트 정보 가져오기
        if (_currentMeeting!.hostId != _currentUserId) {
          final hostUser = await UserService.getUser(_currentMeeting!.hostId);
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
    if (_currentMeeting == null || _currentMeeting!.participantIds.isEmpty) {
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
      
      for (final participantId in _currentMeeting!.participantIds) {
        final user = await UserService.getUser(participantId);
        if (user != null) {
          participantUsers.add(user);
        }
      }
      
      // 호스트를 맨 앞으로 정렬
      participantUsers.sort((a, b) {
        if (a.id == _currentMeeting!.hostId) return -1;
        if (b.id == _currentMeeting!.hostId) return 1;
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

  /// 모임 데이터 새로고침 (승인 처리 후 상태 업데이트용)
  Future<void> _refreshMeetingData() async {
    try {
      if (kDebugMode) {
        print('🔄 모임 데이터 새로고침 시작...');
      }

      // Firestore에서 최신 모임 데이터 가져오기
      final updatedMeeting = await MeetingService.getMeeting(widget.meeting.id);
      if (updatedMeeting != null) {
        setState(() {
          _currentMeeting = updatedMeeting;
        });

        if (kDebugMode) {
          print('✅ 모임 데이터 새로고침 완료');
          print('  - 참여자 수: ${_currentMeeting!.participantIds.length}명');
          print('  - 대기자 수: ${_currentMeeting!.pendingApplicantIds.length}명');
        }

        // 사용자 상태 재계산
        if (_currentUserId != null) {
          setState(() {
            _isJoined = _currentMeeting!.participantIds.contains(_currentUserId);
            _isPending = _currentMeeting!.pendingApplicantIds.contains(_currentUserId);
          });

          if (kDebugMode) {
            print('🔄 사용자 상태 업데이트:');
            print('  - 참여 여부: $_isJoined');
            print('  - 대기 여부: $_isPending');
          }
        }

        // 참여자 목록 새로고침
        await _loadParticipants();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 데이터 새로고침 실패: $e');
      }
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

        // 참여 상태 및 신청 상태 실시간 업데이트
        final isCurrentlyJoined = currentMeeting.participantIds.contains(_currentUserId);
        final isCurrentlyPending = currentMeeting.pendingApplicantIds.contains(_currentUserId);
        
        // 호스트 여부 실시간 업데이트 (UID만 사용)
        final isCurrentlyHost = currentMeeting.hostId == _currentUserId;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppDesignTokens.background,
            foregroundColor: AppDesignTokens.onSurface,
            elevation: 0,
            title: Text('모임 상세', style: AppTextStyles.titleLarge),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshMeetingData,
                tooltip: '새로고침',
              ),
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
                const SizedBox(height: 60), // 버튼 공간 확보
              ],
            ),
          ),
          bottomNavigationBar: _buildJoinButton(currentMeeting, isCurrentlyJoined, isCurrentlyPending, isCurrentlyHost),
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
      padding: const EdgeInsets.all(20),
      margin: AppPadding.vertical8.add(AppPadding.horizontal16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭 바
          Container(
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppDesignTokens.primary,
              unselectedLabelColor: AppDesignTokens.outline,
              indicator: BoxDecoration(
                color: AppDesignTokens.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: AppTextStyles.bodyMedium.semiBold,
              unselectedLabelStyle: AppTextStyles.bodyMedium,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group, size: 18),
                      const SizedBox(width: 8),
                      Text('참여자 (${meeting.currentParticipants})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 18),
                      const SizedBox(width: 8),
                      Text('신청자 (${meeting.pendingApplicantIds.length})'),
                      if (meeting.pendingApplicantIds.isNotEmpty && _isHost)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${meeting.pendingApplicantIds.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          
          // 탭 컨텐츠 (동적 높이)
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final int currentTabIndex = _tabController.index;
              final int userCount = currentTabIndex == 0 
                ? meeting.participantIds.length 
                : meeting.pendingApplicantIds.length;
              
              return SizedBox(
                height: _calculateTabHeight(userCount),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 참여자 탭
                    _buildParticipantList(meeting),
                    // 신청자 탭
                    _buildApplicantList(meeting, meeting.pendingApplicantIds),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildParticipantList(Meeting meeting) {
    if (meeting.participantIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            '참여자가 없습니다',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<app_user.User>>(
      future: _getParticipantUsers(meeting.participantIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AppDesignTokens.primary,
              ),
            ),
          );
        }
        
        final participants = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: participants.length,
          physics: participants.length > 4 
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final participant = participants[index];
            final isHost = participant.id == meeting.hostId;
            return Container(
              margin: EdgeInsets.only(
                bottom: index == participants.length - 1 ? 8 : 12,
              ),
              child: _buildClickableUserRow(
                user: participant,
                isHost: isHost,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApplicantList(Meeting meeting, List<String> pendingApplicantIds) {
    if (pendingApplicantIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            '신청자가 없습니다',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<app_user.User>>(
      future: _getPendingApplicantUsers(pendingApplicantIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AppDesignTokens.primary,
              ),
            ),
          );
        }

        final applicants = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: applicants.length,
          physics: applicants.length > 4 
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final applicant = applicants[index];
            return Container(
              margin: EdgeInsets.only(
                bottom: index == applicants.length - 1 ? 8 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildClickableUserRow(
                      user: applicant,
                      isHost: false,
                    ),
                  ),
                  if (_isHost) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 55,
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () => _approveApplicant(meeting.id, applicant.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppDesignTokens.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              '승인',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 55,
                          height: 30,
                          child: OutlinedButton(
                            onPressed: () => _rejectApplicant(meeting.id, applicant.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              '거절',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
        );
      },
    );
  }

  double _calculateTabHeight(int userCount) {
    // 기본 높이 (empty 메시지용) - 줄임
    const double minHeight = 60;
    
    // 사용자 1명당 높이 (padding 포함) - 줄임
    const double itemHeight = 45;
    
    // 최대 4명까지만 높이 증가, 이후는 스크롤
    const int maxVisibleUsers = 4;
    const double maxHeight = minHeight + (maxVisibleUsers * itemHeight);
    
    if (userCount == 0) {
      return minHeight;
    } else if (userCount <= maxVisibleUsers) {
      return minHeight + (userCount * itemHeight);
    } else {
      return maxHeight;
    }
  }

  Widget _buildClickableUserRow({
    required app_user.User user,
    required bool isHost,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                user: user,
                isCurrentUser: user.id == _currentUserId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isHost 
                    ? AppDesignTokens.primary
                    : AppDesignTokens.surfaceContainer,
                backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                    ? Text(
                        user.name[0],
                        style: TextStyle(
                          color: isHost 
                            ? Colors.white
                            : AppDesignTokens.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                          user.name,
                          style: TextStyle(
                            fontWeight: isHost ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              '호스트',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Text(
                        user.bio!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildJoinButton(Meeting meeting, bool isCurrentlyJoined, bool isCurrentlyPending, bool isCurrentlyHost) {
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
        child: isCurrentlyHost ? _buildHostButtons() : _buildParticipantButton(meeting, isCurrentlyJoined, isCurrentlyPending),
      ),
    );
  }
  
  Widget _buildHostButtons() {
    final meeting = _currentMeeting ?? widget.meeting;
    final isCompleted = meeting.status == 'completed';

    return Row(
      children: [
        // 1. 채팅방 (항상 표시)
        Expanded(
          child: CommonButton(
            text: '채팅방',
            variant: ButtonVariant.outline,
            onPressed: () => _showChatRoom(),
            fullWidth: true,
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        
        // 2. 모임완료 또는 참여자 평가
        Expanded(
          child: CommonButton(
            text: isCompleted ? '참여자 평가' : '모임완료',
            variant: ButtonVariant.primary,
            onPressed: isCompleted ? () => _navigateToEvaluation() : () => _completeMeeting(),
            fullWidth: true,
            icon: isCompleted ? const Icon(Icons.star, size: 18, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        
        // 3. 더치페이 계산기 (계산기 아이콘)
        InkWell(
          onTap: () => _showDutchPayCalculator(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: Icon(
              Icons.calculate,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        
        // 4. 모임수정 (연필 아이콘 - 테두리 없음)
        InkWell(
          onTap: () => _editMeeting(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.outline,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: AppDesignTokens.spacing2),
        
        // 5. 모임삭제 (빨간색 쓰레기통 - 테두리 없음)
        InkWell(
          onTap: () => _deleteMeeting(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: const Icon(
              Icons.delete,
              color: Color(0xFFE53935),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildParticipantButton(Meeting meeting, bool isCurrentlyJoined, bool isCurrentlyPending) {
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
              onPressed: () => _showChatRoom(),
              fullWidth: true,
            ),
          ),
        ],
      );
    } else if (isCurrentlyPending) {
      // 승인 대기 상태
      return CommonButton(
        text: '승인 대기중...',
        variant: ButtonVariant.outline,
        onPressed: _isLoading ? null : () async {
          await _cancelApplication();
        },
        isLoading: _isLoading,
        fullWidth: true,
      );
    } else {
      return CommonButton(
        text: meeting.isAvailable ? '모임 신청하기' : '모집 마감',
        variant: ButtonVariant.primary,
        onPressed: (meeting.isAvailable && !_isLoading && _currentUserId != null)
            ? () async {
                await _applyToMeeting();
              }
            : null,
        isLoading: _isLoading,
        fullWidth: true,
      );
    }
  }
  
  Future<void> _showChatRoom() async {
    if (_currentUserId == null) {
      _showErrorMessage('로그인이 필요합니다');
      return;
    }
    
    // 채팅방 입장 전 모임 데이터 새로고침 (승인 처리 반영)
    if (kDebugMode) {
      print('🔄 채팅방 입장 전 모임 데이터 새로고침...');
    }
    await _refreshMeetingData();
    
    // 참여자만 채팅방 입장 가능
    if (!_isJoined && !_isHost) {
      _showErrorMessage('모임에 참여해야 채팅방에 입장할 수 있습니다');
      return;
    }
    
    if (kDebugMode) {
      print('✅ 채팅방 입장 권한 확인 완료');
      print('  - 참여 여부: $_isJoined');
      print('  - 호스트 여부: $_isHost');
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(meeting: _currentMeeting ?? widget.meeting),
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
  
  Future<void> _navigateToEvaluation() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserEvaluationScreen(
          meetingId: widget.meeting.id,
          meeting: _currentMeeting ?? widget.meeting,
        ),
      ),
    );
  }
  
  Future<void> _completeMeeting() async {
    final result = await MeetingAutoCompleteDialog.show(
      context: context,
      meetingName: _currentMeeting?.description ?? widget.meeting.description,
      onComplete: () {
        // 다이얼로그 내부에서 처리됨
      },
      onPostpone: () {
        // 1시간 후 다시 알림 (실제로는 사용되지 않음)
      },
      isManualCompletion: true, // 수동 완료임을 표시
    );

    if (result == null || result == 'cancel') return;

    // result가 'complete_keep' 또는 'complete_close'
    final keepChatActive = result == 'complete_keep';

    try {
      await MeetingService.completeMeeting(widget.meeting.id, keepChatActive: keepChatActive);
      
      // 모임 완료 시스템 메시지 전송
      final systemMessage = keepChatActive 
          ? '모임이 완료되었습니다. 채팅방은 계속 사용할 수 있습니다! 🎉'
          : '모임이 완료되었습니다. 수고하셨습니다! 🎉';
      
      await ChatService.sendSystemMessage(
        meetingId: widget.meeting.id,
        content: systemMessage,
      );

      if (kDebugMode) {
        print('✅ 모임 완료 성공: ${widget.meeting.id}, 채팅방 유지: $keepChatActive');
      }

      if (mounted) {
        final snackMessage = keepChatActive
            ? '모임이 완료되었습니다!\n채팅방은 계속 사용 가능합니다 💬'
            : '모임이 완료되었습니다!\n채팅방이 읽기 전용으로 전환됩니다 📖';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMessage),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
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
  
  Future<void> _deleteMeeting() async {
    final confirmed = await CommonConfirmDialog.showDelete(
      context: context,
      title: '모임 삭제',
      content: '정말로 모임을 삭제하시겠습니까?\n삭제된 모임은 복구할 수 없습니다.',
      confirmText: '삭제',
    );
    
    if (confirmed) {
      await _performDeleteMeeting();
    }
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
  
  Future<void> _applyToMeeting() async {
    if (_currentUserId == null) {
      _showErrorMessage('로그인이 필요합니다');
      return;
    }
    
    // 최신 모임 데이터로 다시 확인
    await _refreshMeetingData();
    final currentMeeting = _currentMeeting ?? widget.meeting;
    
    // 모집 종료 체크
    if (!currentMeeting.isAvailable) {
      _showErrorMessage('모집이 종료된 모임입니다');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await MeetingService.applyToMeeting(widget.meeting.id, _currentUserId!);
      
      // 신청 성공 후 즉시 데이터 새로고침
      await _refreshMeetingData();
      
      if (kDebugMode) {
        print('✅ 모임 신청 성공: ${widget.meeting.id}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('모임 신청이 완료되었습니다! 🎉\n호스트의 승인을 기다려주세요.\n(호스트에게 알림이 전송되었습니다)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 신청 실패: $e');
      }
      
      String errorMessage = '모임 신청에 실패했습니다';
      IconData errorIcon = Icons.error;
      
      if (e.toString().contains('Already applied')) {
        errorMessage = '이미 신청한 모임입니다';
        errorIcon = Icons.info;
      } else if (e.toString().contains('Already joined')) {
        errorMessage = '이미 참여한 모임입니다';
        errorIcon = Icons.info;
      } else if (e.toString().contains('Meeting is full')) {
        errorMessage = '모임이 찬습니다';
        errorIcon = Icons.group;
      } else if (e.toString().contains('Cannot apply to your own meeting')) {
        errorMessage = '본인이 주최한 모임에는 신청할 수 없습니다';
        errorIcon = Icons.person;
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = '권한이 없습니다. 다시 로그인해주세요';
        errorIcon = Icons.lock;
      } else if (e.toString().contains('network')) {
        errorMessage = '네트워크 연결을 확인해주세요';
        errorIcon = Icons.wifi_off;
      }
      
      _showEnhancedErrorMessage(errorMessage, errorIcon);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _cancelApplication() async {
    if (_currentUserId == null) {
      _showErrorMessage('로그인이 필요합니다');
      return;
    }
    
    final confirmed = await CommonConfirmDialog.showWarning(
      context: context,
      title: '신청 취소',
      content: '모임 신청을 취소하시겠습니까?',
      cancelText: '아니오',
      confirmText: '취소',
    );

    if (!confirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await MeetingService.rejectMeetingApplication(widget.meeting.id, _currentUserId!);
      
      setState(() {
        _isPending = false;
      });
      
      if (kDebugMode) {
        print('✅ 모임 신청 취소 성공: ${widget.meeting.id}');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('모임 신청을 취소했습니다'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 신청 취소 실패: $e');
      }
      
      _showErrorMessage('신청 취소에 실패했습니다');
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
  


  Future<List<app_user.User>> _getPendingApplicantUsers(List<String> applicantIds) async {
    final List<app_user.User> users = [];
    
    for (final applicantId in applicantIds) {
      final user = await UserService.getUser(applicantId);
      if (user != null) {
        users.add(user);
      }
    }
    
    return users;
  }

  Future<void> _approveApplicant(String meetingId, String applicantId) async {
    try {
      // 로딩 상태 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppDesignTokens.primary,
          ),
        ),
      );
      
      await MeetingService.approveMeetingApplication(meetingId, applicantId);
      
      if (kDebugMode) {
        print('✅ 신청자 승인 성공: $applicantId');
      }
      
      // 모임 데이터 새로고침
      await _refreshMeetingData();
      
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      _showSuccessMessage('신청자를 승인했습니다! 🎉', icon: Icons.check_circle);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 신청자 승인 실패: $e');
      }
      
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      String errorMessage = '신청자 승인에 실패했습니다';
      if (e.toString().contains('Meeting is full')) {
        errorMessage = '모임이 이미 가득 찼습니다';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = '승인 권한이 없습니다';
      }
      
      _showEnhancedErrorMessage(errorMessage, Icons.error);
    }
  }

  Future<void> _rejectApplicant(String meetingId, String applicantId) async {
    try {
      // 로딩 상태 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppDesignTokens.primary,
          ),
        ),
      );
      
      await MeetingService.rejectMeetingApplication(meetingId, applicantId);
      
      if (kDebugMode) {
        print('✅ 신청자 거절 성공: $applicantId');
      }
      
      // 모임 데이터 새로고침
      await _refreshMeetingData();
      
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      _showSuccessMessage('신청자를 거절했습니다', icon: Icons.block);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 신청자 거절 실패: $e');
      }
      
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      String errorMessage = '신청자 거절에 실패했습니다';
      if (e.toString().contains('permission-denied')) {
        errorMessage = '거절 권한이 없습니다';
      }
      
      _showEnhancedErrorMessage(errorMessage, Icons.error);
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showEnhancedErrorMessage(String message, IconData icon) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  void _showSuccessMessage(String message, {IconData? icon}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon ?? Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  // 더치페이 계산기 열기
  void _showDutchPayCalculator() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => DutchPayCalculator(
        participantCount: _currentMeeting?.currentParticipants ?? widget.meeting.currentParticipants,
        meetingName: _currentMeeting?.restaurantName ?? widget.meeting.restaurantName ?? widget.meeting.location,
      ),
    );
    
    // 결과가 있으면 채팅방에 전송
    if (result != null && result.isNotEmpty) {
      try {
        await ChatService.sendSystemMessage(
          meetingId: widget.meeting.id,
          content: result,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('더치페이 계산 결과를 채팅방에 공유했습니다'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('채팅방 공유 실패: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // 자동 완료 조건 체크
  void _checkAutoCompletion() {
    // 호스트가 아니거나 이미 완료된 모임이면 체크 안 함
    if (!_isHost || (widget.meeting.status == 'completed')) return;

    final meeting = _currentMeeting ?? widget.meeting;
    final now = DateTime.now();
    final autoCompleteTime = meeting.dateTime.add(const Duration(hours: 2));

    // 모임 시간 + 2시간이 지났으면 자동 완료 다이얼로그 표시
    if (now.isAfter(autoCompleteTime)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAutoCompleteDialog();
      });
    }
  }

  // 자동 완료 다이얼로그 표시
  void _showAutoCompleteDialog() {
    final meeting = _currentMeeting ?? widget.meeting;
    
    MeetingAutoCompleteDialog.show(
      context: context,
      meetingName: meeting.restaurantName ?? meeting.location,
      onComplete: () {
        // 모임 완료 처리
        _completeMeeting();
      },
      onPostpone: () {
        // 1시간 후 재알림 예약
        MeetingAutoCompletionService.postponeMeetingAutoCompletion(
          meeting.id,
          meeting.restaurantName ?? meeting.location,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('1시간 후 다시 알림드리겠습니다'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }
}