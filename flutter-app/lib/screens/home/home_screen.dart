import 'package:flutter/material.dart';
import '../../models/meeting.dart';
import '../../components/meeting_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Meeting> get _filteredMeetings {
    if (_searchQuery.isEmpty) return _sampleMeetings;
    return _sampleMeetings.where((meeting) {
      return meeting.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             meeting.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             meeting.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             meeting.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          _MeetingListTab(meetings: _filteredMeetings),
          const _MapTab(),
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
  
  const _MeetingListTab({required this.meetings});

  @override
  State<_MeetingListTab> createState() => _MeetingListTabState();
}

class _MeetingListTabState extends State<_MeetingListTab> {
  String _selectedFilter = '전체';
  final List<String> _filters = ['전체', '모집중', '일식', '카페', '브런치', '강남', '홍대'];

  List<Meeting> get _filteredMeetings {
    if (_selectedFilter == '전체') return widget.meetings;
    if (_selectedFilter == '모집중') return widget.meetings.where((m) => m.isAvailable).toList();
    return widget.meetings.where((meeting) {
      return meeting.tags.contains(_selectedFilter) || 
             meeting.location.contains(_selectedFilter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayMeetings = _filteredMeetings;
    
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
      child: CustomScrollView(
        slivers: [
          // 필터 칩들
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      selectedColor: Theme.of(context).colorScheme.primary, // 베이지 포인트!
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected 
                            ? Colors.white  // 선택시 흰 글씨
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 모임 리스트
          if (displayMeetings.isEmpty)
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
                    final meeting = displayMeetings[index];
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
                  childCount: displayMeetings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '지도',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '카카오맵 연동 예정',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListTab extends StatelessWidget {
  const _ChatListTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '채팅',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '참여 중인 모임이 없어요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey,
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '프로필',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '로그인 정보 연동 예정',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}