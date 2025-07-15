import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting.dart';
import '../../models/user.dart';
import '../../services/meeting_service.dart';
import '../../services/auth_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../components/meeting_card.dart';

class MyMeetingsHistoryScreen extends StatefulWidget {
  const MyMeetingsHistoryScreen({super.key});

  @override
  State<MyMeetingsHistoryScreen> createState() => _MyMeetingsHistoryScreenState();
}

class _MyMeetingsHistoryScreenState extends State<MyMeetingsHistoryScreen>
    with TickerProviderStateMixin {
  String? _currentUserId;
  List<Meeting> _myMeetings = [];
  List<Meeting> _upcomingMeetings = [];
  List<Meeting> _completedMeetings = [];
  bool _isLoading = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyMeetings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyMeetings() async {
    try {
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUserId = currentFirebaseUser.uid;

      // 모든 모임 가져오기
      final allMeetings = await MeetingService.getMeetingsStream().first;

      if (mounted) {
        // 내가 참여한 모임들 필터링
        final myMeetings = allMeetings.where((meeting) {
          return meeting.participantIds.contains(_currentUserId) ||
              meeting.hostId == _currentUserId;
        }).toList();

        // 예정/완료 모임 분류 - status 기준으로 변경
        _upcomingMeetings = myMeetings
            .where((m) => m.status != 'completed')  // completed가 아닌 모든 모임
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime)); // 날짜순 정렬

        _completedMeetings = myMeetings
            .where((m) => m.status == 'completed')  // completed 상태인 모임만
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // 최신순 정렬

        setState(() {
          _myMeetings = myMeetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 내 모임 로드 실패: $e');
      }
      setState(() => _isLoading = false);
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
          '내 모임',
          style: AppTextStyles.titleLarge,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: Colors.transparent, // 검은 선 제거
          dividerColor: Colors.transparent, // TabBar 아래 선 제거
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upcoming, size: 18), // 아이콘 크기 조정
                  const SizedBox(width: 6),
                  Text(
                    '예정 (${_upcomingMeetings.length})',
                    style: const TextStyle(fontSize: 16), // 글자 크기 명시
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18), // 아이콘 크기 조정
                  const SizedBox(width: 6),
                  Text(
                    '완료 (${_completedMeetings.length})',
                    style: const TextStyle(fontSize: 16), // 글자 크기 명시
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myMeetings.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMeetingsList(_upcomingMeetings, '예정된 모임이 없습니다'),
                    _buildMeetingsList(_completedMeetings, '완료된 모임이 없습니다'),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '참여한 모임이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '새로운 모임을 찾아보세요!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsList(List<Meeting> meetings, String emptyMessage) {
    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_note,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return MeetingCard(
          meeting: meeting,
          currentUserId: _currentUserId,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/meeting-detail',
              arguments: meeting,
            );
          },
        );
      },
    );
  }
}