import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import '../../models/meeting.dart';
import '../../components/meeting_card.dart';
import '../../components/kakao_webview_map.dart';
import '../../components/kakao_web_map.dart';
import '../../components/webview_test.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  // 공유 필터 상태
  String _selectedStatusFilter = '전체'; // '전체', '모집중'
  String _selectedTimeFilter = '최근 일주일'; // '최근 일주일', '전체기간', '과거 포함'

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  void _updateStatusFilter(String filter) {
    setState(() {
      _selectedStatusFilter = filter;
    });
  }
  
  void _updateTimeFilter(String filter) {
    setState(() {
      _selectedTimeFilter = filter;
    });
  }

  List<Meeting> get _filteredMeetings {
    List<Meeting> meetings = List.from(_sampleMeetings);
    
    // 1. 시간 필터 적용
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    
    if (_selectedTimeFilter == '최근 일주일') {
      meetings = meetings.where((meeting) => 
        meeting.dateTime.isAfter(now) && 
        meeting.dateTime.isBefore(now.add(const Duration(days: 7)))
      ).toList();
    } else if (_selectedTimeFilter == '전체기간') {
      meetings = meetings.where((meeting) => meeting.dateTime.isAfter(now)).toList();
    }
    // '과거 포함'은 모든 모임 포함 (필터링 없음)
    
    // 2. 상태 필터 적용
    if (_selectedStatusFilter == '모집중') {
      meetings = meetings.where((meeting) => meeting.isAvailable).toList();
    }
    
    // 3. 검색어 필터 적용
    if (_searchQuery.isNotEmpty) {
      meetings = meetings.where((meeting) {
        return meeting.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               meeting.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               meeting.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               meeting.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }
    
    // 4. 날짜순 정렬 (가장 가까운 미래가 위로)
    meetings.sort((a, b) {
      final now = DateTime.now();
      
      // 미래 모임과 과거 모임 분리
      final aIsFuture = a.dateTime.isAfter(now);
      final bIsFuture = b.dateTime.isAfter(now);
      
      if (aIsFuture && bIsFuture) {
        // 둘 다 미래: 가까운 순서로
        return a.dateTime.compareTo(b.dateTime);
      } else if (!aIsFuture && !bIsFuture) {
        // 둘 다 과거: 최근 순서로
        return b.dateTime.compareTo(a.dateTime);
      } else {
        // 미래 모임이 과거 모임보다 위로
        return aIsFuture ? -1 : 1;
      }
    });
    
    return meetings;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Meeting> _sampleMeetings = [
    Meeting(
      id: '1',
      title: '강남 맛집 탐방하실 분!',
      description: '강남역 근처 유명한 일식집에서 같이 저녁 드실 분 모집합니다. 혼자 가기엔 양이 많아서요 ㅠㅠ',
      location: '강남역 스시로 강남점',
      dateTime: DateTime.now().add(const Duration(hours: 3)),
      maxParticipants: 4,
      currentParticipants: 2,
      hostName: '김민수',
      tags: ['일식', '강남', '저녁'],
    ),
    Meeting(
      id: '2',
      title: '홍대 핫플 카페 투어',
      description: '인스타에서 본 홍대 카페들 돌아다니며 디저트 먹방! 사진도 서로 찍어줘요~',
      location: '홍대입구역 일대',
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      maxParticipants: 3,
      currentParticipants: 1,
      hostName: '박지영',
      tags: ['카페', '디저트', '홍대', '사진'],
    ),
    Meeting(
      id: '3',
      title: '이태원 멕시칸 맛집',
      description: '이태원 멕시칸 음식 맛집에서 타코와 부리토 먹어요! 양이 많아서 나눠먹으면 좋을 것 같아요.',
      location: '이태원 엘 또 타코',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      maxParticipants: 4,
      currentParticipants: 4,
      hostName: '이준호',
      tags: ['멕시칸', '이태원', '점심'],
    ),
    Meeting(
      id: '4',
      title: '성수동 브unch 맛집',
      description: '성수동 감성 카페에서 브런치 먹고 산책해요~ 20대 여성분들 환영!',
      location: '성수역 어니언',
      dateTime: DateTime.now().add(const Duration(days: 3, hours: -2)),
      maxParticipants: 3,
      currentParticipants: 2,
      hostName: '최서연',
      tags: ['브런치', '성수동', '카페', '산책'],
    ),
    Meeting(
      id: '5',
      title: '어제 다녀온 용산 맛집',
      description: '어제 용산 아이파크몰에서 맛있게 먹었던 곳이에요! 후기 공유합니다.',
      location: '용산 아이파크몰 푸드코트',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      maxParticipants: 4,
      currentParticipants: 4,
      hostName: '박민지',
      tags: ['한식', '용산', '후기'],
    ),
    Meeting(
      id: '6',
      title: '지난주 건대 치킨집',
      description: '지난주에 건대에서 먹었던 치킨이 너무 맛있었어요! 다시 가실 분?',
      location: '건대입구 굽네치킨',
      dateTime: DateTime.now().subtract(const Duration(days: 5)),
      maxParticipants: 3,
      currentParticipants: 2,
      hostName: '김철수',
      tags: ['치킨', '건대', '재방문'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1 ? null : AppBar( // 지도 탭일 때 앱바 숨김
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        elevation: 0,
        title: _selectedIndex == 0 && _searchQuery.isNotEmpty
            ? TextField(
                controller: _searchController,
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                decoration: const InputDecoration(
                  hintText: '모임 검색...',
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.clear),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : null,  // 제목 제거
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(_searchQuery.isEmpty ? Icons.search : Icons.close),
              onPressed: () {
                setState(() {
                  if (_searchQuery.isEmpty) {
                    _searchQuery = ' '; // 검색 모드 활성화
                    _searchController.clear();
                  } else {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: 알림 페이지로 이동
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _MeetingListTab(
            meetings: _filteredMeetings,
            selectedStatusFilter: _selectedStatusFilter,
            selectedTimeFilter: _selectedTimeFilter,
            onStatusFilterChanged: _updateStatusFilter,
            onTimeFilterChanged: _updateTimeFilter,
          ),
          _MapTab(
            selectedStatusFilter: _selectedStatusFilter,
            selectedTimeFilter: _selectedTimeFilter,
            onStatusFilterChanged: _updateStatusFilter,
            onTimeFilterChanged: _updateTimeFilter,
          ),
          const _ChatListTab(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              heroTag: "home_create_fab",
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/create-meeting');
                if (result is Meeting) {
                  setState(() {
                    _sampleMeetings.insert(0, result);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('새로운 모임이 생성되었습니다!')),
                  );
                }
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _MeetingListTab extends StatefulWidget {
  final List<Meeting> meetings;
  final String selectedStatusFilter;
  final String selectedTimeFilter;
  final Function(String) onStatusFilterChanged;
  final Function(String) onTimeFilterChanged;
  
  const _MeetingListTab({
    required this.meetings,
    required this.selectedStatusFilter,
    required this.selectedTimeFilter,
    required this.onStatusFilterChanged,
    required this.onTimeFilterChanged,
  });

  @override
  State<_MeetingListTab> createState() => _MeetingListTabState();
}

class _MeetingListTabState extends State<_MeetingListTab> {
  final List<String> _statusFilters = ['전체', '모집중'];
  final List<String> _timeFilters = ['최근 일주일', '전체기간', '과거 포함'];

  @override
  Widget build(BuildContext context) {
    if (widget.meetings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '아직 모임이 없어요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '첫 번째 모임을 만들어보세요!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: 모임 리스트 새로고침
        await Future.delayed(const Duration(seconds: 1));
      },
      child: Stack(
        children: [
          // 모임 리스트
          CustomScrollView(
            slivers: [
              // 필터 영역을 위한 여백
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
              
              // 모임 리스트
              if (widget.meetings.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '조건에 맞는 모임이 없어요',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '다른 필터를 선택해보세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final meeting = widget.meetings[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          curve: Curves.easeOutBack,
                          child: MeetingCard(
                            meeting: meeting,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/meeting-detail',
                                arguments: meeting,
                              );
                            },
                          ),
                        );
                      },
                      childCount: widget.meetings.length,
                    ),
                  ),
                ),
            ],
          ),
          
          // 플로팅 필터들 (지도와 같은 스타일)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // 상태 필터 (전체, 모집중)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusFilters.length,
                    itemBuilder: (context, index) {
                      final filter = _statusFilters[index];
                      final isSelected = widget.selectedStatusFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                widget.onStatusFilterChanged(filter);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected 
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 시간 필터 (최근 일주일, 전체기간, 과거 포함)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _timeFilters.length,
                    itemBuilder: (context, index) {
                      final filter = _timeFilters[index];
                      final isSelected = widget.selectedTimeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                widget.onTimeFilterChanged(filter);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected 
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTab extends StatefulWidget {
  final String selectedStatusFilter;
  final String selectedTimeFilter;
  final Function(String) onStatusFilterChanged;
  final Function(String) onTimeFilterChanged;
  
  const _MapTab({
    required this.selectedStatusFilter,
    required this.selectedTimeFilter,
    required this.onStatusFilterChanged,
    required this.onTimeFilterChanged,
  });

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusFilters = ['전체', '모집중'];
  final List<String> _timeFilters = ['최근 일주일', '전체기간', '과거 포함'];
  KakaoMapController? _mapController;
  
  // 하단 카드 관련 상태
  bool _showBottomCard = false;
  MapMeeting? _selectedMeeting;
  
  // 샘플 지도 데이터 (실제로는 API에서 가져올 데이터)
  final List<MapMeeting> _mapMeetings = [
    MapMeeting(
      id: '1',
      title: '강남 맛집 탐방하실 분!',
      location: '강남역 스시로 강남점',
      latitude: 37.498095,
      longitude: 127.02761,
      participantCount: 2,
      maxParticipants: 4,
      tag: '일식',
    ),
    MapMeeting(
      id: '2',
      title: '홍대 핫플 카페 투어',
      location: '홍대입구역 일대',
      latitude: 37.556785,
      longitude: 126.922497,
      participantCount: 1,
      maxParticipants: 3,
      tag: '카페',
    ),
    MapMeeting(
      id: '3',
      title: '성수동 브런치 맛집',
      location: '성수역 어니언',
      latitude: 37.544581,
      longitude: 127.055961,
      participantCount: 2,
      maxParticipants: 3,
      tag: '브런치',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  void _onMarkerClicked(String meetingId) {
    final meeting = _mapMeetings.firstWhere(
      (m) => m.id == meetingId,
      orElse: () => _mapMeetings.first,
    );
    
    setState(() {
      _selectedMeeting = meeting;
      _showBottomCard = true;
    });
  }
  
  void _joinMeeting(MapMeeting meeting) {
    // 참석자 수 증가
    setState(() {
      final index = _mapMeetings.indexWhere((m) => m.id == meeting.id);
      if (index != -1 && _mapMeetings[index].participantCount < _mapMeetings[index].maxParticipants) {
        _mapMeetings[index] = MapMeeting(
          id: meeting.id,
          title: meeting.title,
          location: meeting.location,
          latitude: meeting.latitude,
          longitude: meeting.longitude,
          participantCount: meeting.participantCount + 1,
          maxParticipants: meeting.maxParticipants,
          tag: meeting.tag,
        );
        _selectedMeeting = _mapMeetings[index]; // 업데이트된 정보로 변경
      }
      _showBottomCard = false;
      _selectedMeeting = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('모임에 참석 신청했습니다! 🎉'),
        backgroundColor: Color(0xFFD2B48C),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _goToMeetingDetail(MapMeeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });
    
    // 모임 상세 페이지로 이동 (Meeting 객체로 변환)
    final detailMeeting = Meeting(
      id: meeting.id,
      title: meeting.title,
      description: '${meeting.location}에서 함께 식사하실 분들을 모집합니다!',
      location: meeting.location,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      maxParticipants: meeting.maxParticipants,
      currentParticipants: meeting.participantCount,
      hostName: '모임장',
      tags: [meeting.tag],
    );
    
    Navigator.pushNamed(
      context,
      '/meeting-detail',
      arguments: detailMeeting,
    ).then((_) {
      // 상세 페이지에서 돌아왔을 때 지도 상태 업데이트
      setState(() {});
    });
  }
  
  
  List<MapMarker> _getFilteredMarkers() {
    // 상태 필터에 맞는 모임들만 표시
    final filteredMeetings = _mapMeetings.where((meeting) {
      if (widget.selectedStatusFilter == '모집중') {
        return meeting.participantCount < meeting.maxParticipants;
      }
      return true; // '전체'인 경우 모든 모임 포함
    }).toList();
    
    // MapMeeting을 MapMarker로 변환 (모바일용)
    return filteredMeetings.map((meeting) => MapMarker(
      id: meeting.id,
      latitude: meeting.latitude,
      longitude: meeting.longitude,
      title: '${meeting.location} (${meeting.participantCount}/${meeting.maxParticipants})',
    )).toList();
  }
  
  List<WebMapMarker> _getFilteredWebMarkers() {
    // 상태 필터에 맞는 모임들만 표시
    final filteredMeetings = _mapMeetings.where((meeting) {
      if (widget.selectedStatusFilter == '모집중') {
        return meeting.participantCount < meeting.maxParticipants;
      }
      return true; // '전체'인 경우 모든 모임 포함
    }).toList();
    
    // MapMeeting을 WebMapMarker로 변환 (웹용)
    return filteredMeetings.map((meeting) => WebMapMarker(
      id: meeting.id,
      latitude: meeting.latitude,
      longitude: meeting.longitude,
      title: '${meeting.location} (${meeting.participantCount}/${meeting.maxParticipants})',
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        // 터치 시작 시 하단 카드 닫기 (WebView 터치도 감지)
        if (_showBottomCard) {
          // 하단 카드 영역이 아닌 경우에만 닫기
          final bottomCardTop = MediaQuery.of(context).size.height - 200;
          if (event.position.dy < bottomCardTop) {
            setState(() {
              _showBottomCard = false;
              _selectedMeeting = null;
            });
          }
        }
      },
      child: Stack(
        children: [
          // 풀스크린 카카오맵 (StatusBar까지)
          Positioned.fill(
            child: kIsWeb 
              ? KakaoWebMap(
                  latitude: 37.5665, // 서울시청 기본 위치
                  longitude: 126.9780,
                  level: 10,
                  markers: _getFilteredWebMarkers(),
                )
              : KakaoWebViewMap(
                  latitude: 37.5665, // 서울시청 기본 위치
                  longitude: 126.9780,
                  level: 10,
                  markers: _getFilteredMarkers(),
                  onMarkerClicked: _onMarkerClicked,
                ),
          ),
        
        // 상단 오버레이 UI (터치 이벤트 통과)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: IgnorePointer(
            ignoring: false, // 검색바와 필터는 클릭 가능
            child: Column(
            children: [
              // 검색바 (플로팅)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '지역이나 식당을 검색하세요',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    // TODO: 검색 기능 구현
                  },
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 상태 필터 (전체, 모집중)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statusFilters.length,
                  itemBuilder: (context, index) {
                    final filter = _statusFilters[index];
                    final isSelected = widget.selectedStatusFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              widget.onStatusFilterChanged(filter);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected 
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 시간 필터 (최근 일주일, 전체기간, 과거 포함)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _timeFilters.length,
                  itemBuilder: (context, index) {
                    final filter = _timeFilters[index];
                    final isSelected = widget.selectedTimeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              widget.onTimeFilterChanged(filter);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected 
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            ),
          ),
        ),
        
        // 현재 위치 버튼 (우측 상단)
        Positioned(
          top: MediaQuery.of(context).padding.top + 160, // 검색바와 두 줄 필터 아래
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('현재 위치로 이동'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.my_location,
                    size: 24,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // 하단 모임 카드 (슬라이드 애니메이션)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showBottomCard ? 16 : -200,
          left: 16,
          right: 16,
          child: _showBottomCard && _selectedMeeting != null
              ? _buildMeetingCard(_selectedMeeting!)
              : const SizedBox.shrink(),
        ),
        ],
      ),
    );
  }
  
  Widget _buildMeetingCard(MapMeeting meeting) {
    return GestureDetector(
      onTap: () {
        // 카드 클릭 시 외부 GestureDetector로 이벤트 전파 방지
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들 바
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 모임 정보
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목과 상태
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meeting.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: meeting.participantCount < meeting.maxParticipants
                              ? const Color(0xFFD2B48C) // 베이지 컬러
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          meeting.participantCount < meeting.maxParticipants ? '모집중' : '마감',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 위치 정보
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meeting.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 참여자 수와 태그
                  Row(
                    children: [
                      Icon(
                        Icons.group,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${meeting.participantCount}/${meeting.maxParticipants}명',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          meeting.tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 액션 버튼들
                  Row(
                    children: [
                      // 참석하기 버튼
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: meeting.participantCount < meeting.maxParticipants
                              ? () {
                                  _joinMeeting(meeting);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD2B48C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            meeting.participantCount < meeting.maxParticipants ? '참석하기' : '마감',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // 상세보기 버튼
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _goToMeetingDetail(meeting);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD2B48C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '상세보기',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD2B48C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // 닫기 버튼
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showBottomCard = false;
                            _selectedMeeting = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.grey[600],
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
  
  void _showMeetingInfo(MapMeeting meeting) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: Text(
                    meeting.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '모집중',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    meeting.location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${meeting.participantCount}/${meeting.maxParticipants}명',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meeting.tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: 모임 상세 페이지로 이동
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('모임 상세 페이지로 이동'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
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
                  '모임 상세보기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 지도용 모임 데이터 모델
class MapMeeting {
  final String id;
  final String title;
  final String location;
  final double latitude;
  final double longitude;
  final int participantCount;
  final int maxParticipants;
  final String tag;

  MapMeeting({
    required this.id,
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.participantCount,
    required this.maxParticipants,
    required this.tag,
  });
}

class _ChatListTab extends StatefulWidget {
  const _ChatListTab();

  @override
  State<_ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<_ChatListTab> {
  // 샘플 채팅방 데이터
  final List<ChatRoom> _chatRooms = [
    ChatRoom(
      id: '1',
      meetingTitle: '강남 맛집 탐방하실 분!',
      lastMessage: '내일 6시에 만날까요?',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 2,
      participantCount: 3,
      isActive: true,
      hostName: '김민수',
    ),
    ChatRoom(
      id: '2',
      meetingTitle: '홍대 핫플 카페 투어',
      lastMessage: '사진 공유해주세요~',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 0,
      participantCount: 2,
      isActive: true,
      hostName: '박지영',
    ),
    ChatRoom(
      id: '3',
      meetingTitle: '이태원 멕시칸 맛집',
      lastMessage: '맛있게 잘 먹었습니다!',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      participantCount: 4,
      isActive: false,
      hostName: '이준호',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_chatRooms.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // 상단 헤더
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Text(
                '채팅',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_chatRooms.where((room) => room.isActive).length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 채팅방 리스트
        Expanded(
          child: ListView.builder(
            itemCount: _chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = _chatRooms[index];
              return _buildChatRoomItem(chatRoom);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '채팅',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '참여 중인 모임이 없어요',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // 홈 탭으로 이동
              setState(() {}); // 임시
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('홈에서 모임에 참여해보세요!'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('모임 찾아보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomItem(ChatRoom chatRoom) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChatRoom(chatRoom),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 모임 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: chatRoom.isActive 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant,
                    color: chatRoom.isActive 
                      ? Colors.white
                      : Theme.of(context).colorScheme.outline,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 채팅 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chatRoom.meetingTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(chatRoom.lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chatRoom.lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          if (chatRoom.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                chatRoom.unreadCount > 99 ? '99+' : '${chatRoom.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          Icon(
                            Icons.group,
                            size: 14,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${chatRoom.participantCount}명',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (!chatRoom.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '종료된 모임',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.outline,
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
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '방금';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _openChatRoom(ChatRoom chatRoom) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          meetingTitle: chatRoom.meetingTitle,
          chatRoomId: chatRoom.id,
        ),
      ),
    );
  }
}

// 채팅방 데이터 모델
class ChatRoom {
  final String id;
  final String meetingTitle;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final int participantCount;
  final bool isActive;
  final String hostName;

  ChatRoom({
    required this.id,
    required this.meetingTitle,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.participantCount,
    required this.isActive,
    required this.hostName,
  });
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  // 샘플 사용자 데이터
  final UserProfile _userProfile = UserProfile(
    name: '김민수',
    profileImage: null,
    joinDate: DateTime.now().subtract(const Duration(days: 30)),
    totalMeetings: 12,
    hostMeetings: 5,
    averageRating: 4.2,
    ratings: UserRatings(
      timeKeeping: 4.5,
      conversationManner: 4.0,
      reMeetingIntent: 4.1,
    ),
    badges: ['🆕 신규', '👑 매너왕'],
  );

  // 샘플 내 모임 히스토리
  final List<MyMeetingHistory> _myMeetings = [
    MyMeetingHistory(
      id: '1',
      title: '강남 맛집 탐방하실 분!',
      location: '강남역 스시로 강남점',
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: MeetingStatus.completed,
      isHost: true,
      participantCount: 4,
    ),
    MyMeetingHistory(
      id: '2',
      title: '홍대 핫플 카페 투어',
      location: '홍대입구역 일대',
      date: DateTime.now().add(const Duration(days: 1)),
      status: MeetingStatus.upcoming,
      isHost: false,
      participantCount: 3,
    ),
    MyMeetingHistory(
      id: '3',
      title: '성수동 브런치 맛집',
      location: '성수역 어니언',
      date: DateTime.now().subtract(const Duration(days: 7)),
      status: MeetingStatus.completed,
      isHost: false,
      participantCount: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 프로필 헤더
          _buildProfileHeader(),
          
          // 통계 정보
          _buildStatsSection(),
          
          // 평가 정보
          _buildRatingsSection(),
          
          // 내 모임 히스토리
          _buildMyMeetingsSection(),
          
          // 설정 메뉴
          _buildSettingsSection(),
          
          const SizedBox(height: 20),
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
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _userProfile.name[0],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userProfile.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatJoinDate(_userProfile.joinDate)} 가입',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
          
          const SizedBox(height: 16),
          
          // 뱃지들
          if (_userProfile.badges.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _userProfile.badges.map((badge) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
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
          Text(
            '활동 통계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '참여한 모임',
                  '${_userProfile.totalMeetings}회',
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
                  '${_userProfile.hostMeetings}회',
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
                  '${_userProfile.averageRating.toStringAsFixed(1)}점',
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
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
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
          Text(
            '받은 평가',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildRatingItem('⏰ 시간 준수', _userProfile.ratings.timeKeeping),
          const SizedBox(height: 12),
          _buildRatingItem('💬 대화 매너', _userProfile.ratings.conversationManner),
          const SizedBox(height: 12),
          _buildRatingItem('🤝 재만남 의향', _userProfile.ratings.reMeetingIntent),
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
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              );
            }),
          ),
        ),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMyMeetingsSection() {
    final upcomingMeetings = _myMeetings.where((m) => m.status == MeetingStatus.upcoming).toList();
    final completedMeetings = _myMeetings.where((m) => m.status == MeetingStatus.completed).toList();
    
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
                '내 모임',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
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
          if (upcomingMeetings.isNotEmpty) ...[
            Text(
              '예정된 모임 (${upcomingMeetings.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...upcomingMeetings.take(2).map((meeting) => _buildMeetingHistoryItem(meeting)),
            const SizedBox(height: 16),
          ],
          
          // 완료된 모임
          if (completedMeetings.isNotEmpty) ...[
            Text(
              '완료된 모임 (${completedMeetings.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...completedMeetings.take(2).map((meeting) => _buildMeetingHistoryItem(meeting)),
          ],
        ],
      ),
    );
  }

  Widget _buildMeetingHistoryItem(MyMeetingHistory meeting) {
    return Container(
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
              color: meeting.isHost 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant,
              color: meeting.isHost ? Colors.white : Theme.of(context).colorScheme.outline,
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
                        meeting.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (meeting.isHost)
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
                ),
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Text(
                      _formatMeetingDate(meeting.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: meeting.status == MeetingStatus.upcoming
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meeting.status == MeetingStatus.upcoming ? '예정' : '완료',
                        style: TextStyle(
                          fontSize: 10,
                          color: meeting.status == MeetingStatus.upcoming
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
          Text(
            '설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSettingItem(
            Icons.notifications,
            '알림 설정',
            '푸시 알림 및 소리 설정',
            () => _showNotificationSettings(),
          ),
          _buildSettingItem(
            Icons.security,
            '개인정보 설정',
            '프로필 공개 범위 설정',
            () => _showPrivacySettings(),
          ),
          _buildSettingItem(
            Icons.help,
            '고객센터',
            '문의하기 및 도움말',
            () => _showCustomerService(),
          ),
          _buildSettingItem(
            Icons.info,
            '앱 정보',
            '버전 정보 및 이용약관',
            () => _showAppInfo(),
          ),
          const SizedBox(height: 8),
          _buildSettingItem(
            Icons.logout,
            '로그아웃',
            '',
            () => _showLogoutDialog(),
            isLogout: true,
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
                color: isLogout 
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
                        color: isLogout 
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

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference < 30) {
      return '${difference}일 전';
    } else if (difference < 365) {
      return '${(difference / 30).floor()}개월 전';
    } else {
      return '${date.year}년 ${date.month}월';
    }
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

  void _showProfileEdit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('프로필 편집 기능 준비 중'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showAllMeetings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('전체 모임 히스토리 화면으로 이동'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showNotificationSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('알림 설정 화면으로 이동'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showPrivacySettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('개인정보 설정 화면으로 이동'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showCustomerService() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('고객센터 화면으로 이동'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showAppInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('앱 정보 화면으로 이동'),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('로그아웃되었습니다'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
            child: Text('로그아웃', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );
  }
}

// 사용자 프로필 데이터 모델
class UserProfile {
  final String name;
  final String? profileImage;
  final DateTime joinDate;
  final int totalMeetings;
  final int hostMeetings;
  final double averageRating;
  final UserRatings ratings;
  final List<String> badges;

  UserProfile({
    required this.name,
    this.profileImage,
    required this.joinDate,
    required this.totalMeetings,
    required this.hostMeetings,
    required this.averageRating,
    required this.ratings,
    required this.badges,
  });
}

class UserRatings {
  final double timeKeeping;
  final double conversationManner;
  final double reMeetingIntent;

  UserRatings({
    required this.timeKeeping,
    required this.conversationManner,
    required this.reMeetingIntent,
  });
}

// 내 모임 히스토리 데이터 모델
class MyMeetingHistory {
  final String id;
  final String title;
  final String location;
  final DateTime date;
  final MeetingStatus status;
  final bool isHost;
  final int participantCount;

  MyMeetingHistory({
    required this.id,
    required this.title,
    required this.location,
    required this.date,
    required this.status,
    required this.isHost,
    required this.participantCount,
  });
}

enum MeetingStatus {
  upcoming,
  completed,
  cancelled,
}