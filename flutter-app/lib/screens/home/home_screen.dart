import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import '../../models/meeting.dart';
import '../../models/user.dart';
import '../../components/meeting_card.dart';
import '../../components/kakao_webview_map.dart';
import '../../components/kakao_web_map.dart';
import '../../components/webview_test.dart';
import '../../components/hierarchical_location_picker.dart';
import '../../services/meeting_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/location_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/kakao_search_service.dart';
import '../../models/message.dart';
import '../../models/restaurant.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_room_screen.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey<_ChatListTabState> _chatListKey = GlobalKey<_ChatListTabState>();
  final GlobalKey<_MapTabState> _mapKey = GlobalKey<_MapTabState>();
  int _totalUnreadCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeCurrentLocation();
  }
  
  Future<void> _initializeCurrentLocation() async {
    if (_isLocationInitialized) return;
    
    try {
      final currentLocation = await LocationService.getCurrentLocation();
      if (currentLocation != null && mounted) {
        // GPS 위치에서 가장 가까운 도시 찾기
        final nearestCity = LocationService.findNearestCity(
          currentLocation.latitude!,
          currentLocation.longitude!
        );
        
        if (nearestCity != null) {
          setState(() {
            _selectedLocationFilter = nearestCity;
            _isLocationInitialized = true;
          });
          print('📍 홈화면 지역 필터: $nearestCity로 자동 설정됨');
        }
      }
    } catch (e) {
      // GPS 실패하면 기본값 유지
      print('📍 GPS 초기화 실패, 기본값 유지: $e');
      if (mounted) {
        setState(() {
          _isLocationInitialized = true;
        });
      }
    }
  }
  
  // 공유 필터 상태
  String _selectedStatusFilter = '전체'; // '전체', '모집중'
  String _selectedTimeFilter = '일주일'; // '오늘', '내일', '일주일', '전체'
  String _selectedLocationFilter = '전체지역'; // 기본값 (GPS 감지 후 가장 가까운 도시로 자동 설정)
  bool _isLocationInitialized = false;
  
  // 지도 상태 유지를 위한 변수들
  static double? _savedMapLatitude;
  static double? _savedMapLongitude;
  static int? _savedMapLevel;
  static List<Restaurant>? _savedSearchResults;
  static String? _savedSearchQuery;
  static bool? _savedShowSearchResults;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // 지도 탭으로 이동할 때 상태가 제대로 복원되었는지 확인
    if (index == 1) { // 지도 탭
      print('🗺️ 지도 탭 활성화 - 저장된 상태 확인');
      if (_savedMapLatitude != null && _savedMapLongitude != null) {
        print('🗺️ 저장된 지도 위치: $_savedMapLatitude, $_savedMapLongitude');
      }
      if (_savedSearchResults != null) {
        print('🗺️ 저장된 검색 결과: ${_savedSearchResults!.length}개');
      }
    }
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
  
  void _updateLocationFilter(String filter) {
    setState(() {
      _selectedLocationFilter = filter;
    });
  }

  Widget _buildChatIconWithBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat),
        if (_totalUnreadCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(AppDesignTokens.spacing2),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _totalUnreadCount > 99 ? '99+' : '$_totalUnreadCount',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  List<Meeting> _filterMeetings(List<Meeting> meetings) {
    
    // 1. 시간 필터 적용
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));
    
    if (_selectedTimeFilter == '오늘') {
      meetings = meetings.where((meeting) => 
        meeting.dateTime.isAfter(today) && 
        meeting.dateTime.isBefore(tomorrow)
      ).toList();
    } else if (_selectedTimeFilter == '내일') {
      meetings = meetings.where((meeting) => 
        meeting.dateTime.isAfter(tomorrow) && 
        meeting.dateTime.isBefore(tomorrow.add(const Duration(days: 1)))
      ).toList();
    } else if (_selectedTimeFilter == '일주일') {
      meetings = meetings.where((meeting) => 
        meeting.dateTime.isAfter(now) && 
        meeting.dateTime.isBefore(nextWeek)
      ).toList();
    } else if (_selectedTimeFilter == '전체') {
      meetings = meetings.where((meeting) => meeting.dateTime.isAfter(now)).toList();
    }
    
    // 2. 상태 필터 적용
    if (_selectedStatusFilter == '모집중') {
      meetings = meetings.where((meeting) => meeting.isAvailable && meeting.status == 'active').toList();
    } else if (_selectedStatusFilter == '완료') {
      meetings = meetings.where((meeting) => meeting.status == 'completed').toList();
    }
    
    // 2.5. 지역 필터 적용
    if (_selectedLocationFilter != '전체지역') {
      // 특정 도시 선택 시 해당 도시명으로 필터링
      meetings = meetings.where((meeting) => 
        meeting.city == _selectedLocationFilter ||
        meeting.location.contains(_selectedLocationFilter) ||
        meeting.restaurantName?.contains(_selectedLocationFilter) == true
      ).toList();
    }
    // '전체지역'만 모든 모임 표시
    
    // 3. 검색어 필터 적용
    if (_searchQuery.isNotEmpty) {
      meetings = meetings.where((meeting) {
        return (meeting.restaurantName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
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

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
            
            // 헤더
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    '지역 선택',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // 전체지역 및 현재위치 옵션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 전체지역 옵션
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLocationFilter = '전체지역';
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _selectedLocationFilter == '전체지역' 
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.public,
                              color: _selectedLocationFilter == '전체지역' 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '전체지역',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _selectedLocationFilter == '전체지역' 
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: _selectedLocationFilter == '전체지역' ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_selectedLocationFilter == '전체지역')
                              Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 현재위치 옵션
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        // GPS 위치 감지 후 가장 가까운 도시로 설정
                        try {
                          final currentLocation = await LocationService.getCurrentLocation();
                          if (currentLocation != null) {
                            final nearestCity = LocationService.findNearestCity(
                              currentLocation.latitude!,
                              currentLocation.longitude!
                            );
                            if (nearestCity != null) {
                              setState(() {
                                _selectedLocationFilter = nearestCity;
                              });
                            }
                          }
                        } catch (e) {
                          print('GPS 위치 감지 실패: $e');
                        }
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.transparent,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Theme.of(context).colorScheme.outline,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '현재위치',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 계층적 위치 선택기
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  child: HierarchicalLocationPicker(
                    initialCity: _selectedLocationFilter == '전체지역' ? null : _selectedLocationFilter,
                    showCurrentLocation: false,
                    onCitySelected: (cityName) {
                      setState(() {
                        _selectedLocationFilter = cityName;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Meeting>>(
      stream: MeetingService.getMeetingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('데이터를 불러오는 중 오류가 발생했습니다.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        }

        final allMeetings = snapshot.data ?? [];
        final filteredMeetings = _filterMeetings(allMeetings);

        return Scaffold(
      appBar: _selectedIndex == 1 ? null : AppBar( // 지도 탭일 때 앱바 숨김
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: _selectedIndex == 0 
            ? (_searchQuery.isNotEmpty
                ? TextField(
                    controller: _searchController,
                    style: AppTextStyles.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: '모임 검색...',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  )
                : GestureDetector(
                    onTap: () => _showLocationPicker(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedLocationFilter,
                          style: AppTextStyles.headlineMedium,
                        ),
                        const SizedBox(width: AppDesignTokens.spacing1),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: AppDesignTokens.onSurface,
                          size: AppDesignTokens.iconDefault,
                        ),
                      ],
                    ),
                  ))
            : Text(
                _selectedIndex == 2 ? '채팅' : _selectedIndex == 3 ? '마이페이지' : '혼뱥노노',
                style: AppTextStyles.headlineMedium,
              ),
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
            meetings: filteredMeetings,
            selectedStatusFilter: _selectedStatusFilter,
            selectedTimeFilter: _selectedTimeFilter,
            selectedLocationFilter: _selectedLocationFilter,
            onStatusFilterChanged: _updateStatusFilter,
            onTimeFilterChanged: _updateTimeFilter,
            onLocationFilterChanged: _updateLocationFilter,
          ),
          _MapTab(
            key: _mapKey,
            selectedStatusFilter: _selectedStatusFilter,
            selectedTimeFilter: _selectedTimeFilter,
            meetings: filteredMeetings,
            onStatusFilterChanged: _updateStatusFilter,
            onTimeFilterChanged: _updateTimeFilter,
          ),
          _ChatListTab(
            key: _chatListKey,
            onUnreadCountChanged: () {
              final newCount = _chatListKey.currentState?.totalUnreadCount ?? 0;
              if (_totalUnreadCount != newCount) {
                setState(() {
                  _totalUnreadCount = newCount;
                });
              }
            },
          ),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12, // 글씨 크기 고정
        unselectedFontSize: 12, // 글씨 크기 고정
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: _buildChatIconWithBadge(),
            label: '채팅',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              heroTag: "home_create_fab",
              onPressed: () async {
                if (AuthService.currentUserId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인이 필요합니다.')),
                  );
                  return;
                }
                
                final result = await Navigator.pushNamed(context, '/create-meeting');
                // CreateMeetingScreen에서 이미 모임을 생성하고 성공 메시지도 표시했으므로
                // 여기서는 추가 처리가 필요없음 (StreamBuilder가 자동으로 새 데이터를 받아옴)
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
        );
      },
    );
  }
}

class _MeetingListTab extends StatefulWidget {
  final List<Meeting> meetings;
  final String selectedStatusFilter;
  final String selectedTimeFilter;
  final String selectedLocationFilter;
  final Function(String) onStatusFilterChanged;
  final Function(String) onTimeFilterChanged;
  final Function(String) onLocationFilterChanged;
  
  const _MeetingListTab({
    required this.meetings,
    required this.selectedStatusFilter,
    required this.selectedTimeFilter,
    required this.selectedLocationFilter,
    required this.onStatusFilterChanged,
    required this.onTimeFilterChanged,
    required this.onLocationFilterChanged,
  });

  @override
  State<_MeetingListTab> createState() => _MeetingListTabState();
}

class _MeetingListTabState extends State<_MeetingListTab> {
  final List<String> _statusFilters = ['전체', '모집중', '완료'];
  final List<String> _timeFilters = ['오늘', '내일', '일주일', '전체'];
  final List<String> _locationFilters = ['전체', '서울시 중구', '서울시 강남구', '서울시 마포구', '서울시 성동구', '서울시 용산구'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 필터 칩들 (두 줄로 배치)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // 첫 번째 줄: 상태 필터
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._statusFilters.map((filter) => _buildFilterChip(
                      filter, 
                      widget.selectedStatusFilter == filter,
                      () => widget.onStatusFilterChanged(filter),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 두 번째 줄: 시간 필터
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._timeFilters.map((filter) => _buildFilterChip(
                      filter, 
                      widget.selectedTimeFilter == filter,
                      () => widget.onTimeFilterChanged(filter),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 모임 리스트
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // TODO: 모임 리스트 새로고침
              await Future.delayed(const Duration(seconds: 1));
            },
            child: widget.meetings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '조건에 맞는 모임이 없어요',
                          style: TextStyle(
                            fontSize: AppDesignTokens.fontSizeH3,
                            fontWeight: AppDesignTokens.fontWeightSemiBold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '다른 필터를 선택하거나 첫 모임을 만들어보세요!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.meetings.length,
                    itemBuilder: (context, index) {
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
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.black
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMapFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.black
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _MapTab extends StatefulWidget {
  final String selectedStatusFilter;
  final String selectedTimeFilter;
  final List<Meeting> meetings;
  final Function(String) onStatusFilterChanged;
  final Function(String) onTimeFilterChanged;
  
  const _MapTab({
    super.key,
    required this.selectedStatusFilter,
    required this.selectedTimeFilter,
    required this.meetings,
    required this.onStatusFilterChanged,
    required this.onTimeFilterChanged,
  });

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusFilters = ['전체', '모집중'];
  final List<String> _timeFilters = ['오늘', '내일', '일주일', '전체'];
  KakaoMapController? _mapController;
  final GlobalKey<KakaoWebViewMapState> _webMapKey = GlobalKey<KakaoWebViewMapState>();
  final ScrollController _cardScrollController = ScrollController();
  
  // 하단 카드 관련 상태
  bool _showBottomCard = false;
  Meeting? _selectedMeeting;
  
  // 지도 중심 좌표 (현재 위치 기반)
  double _centerLatitude = 37.5665; // 기본값: 서울시청
  double _centerLongitude = 126.9780;
  bool _isLocationInitialized = false;
  
  // 검색 관련 상태
  bool _isSearching = false;
  List<Restaurant> _searchResults = [];
  Restaurant? _selectedRestaurant;
  bool _showSearchResults = false;
  
  @override
  void initState() {
    super.initState();
    _restoreMapState(); // 저장된 지도 상태 복원
    _initializeCurrentLocationSync(); // 동기 방식으로 즉시 위치 설정
  }
  
  void _restoreMapState() {
    // 저장된 지도 상태 복원
    if (_HomeScreenState._savedMapLatitude != null && _HomeScreenState._savedMapLongitude != null) {
      _centerLatitude = _HomeScreenState._savedMapLatitude!;
      _centerLongitude = _HomeScreenState._savedMapLongitude!;
      print('🗺️ 지도 위치 복원: $_centerLatitude, $_centerLongitude');
    }
    
    if (_HomeScreenState._savedSearchResults != null) {
      _searchResults = _HomeScreenState._savedSearchResults!;
      print('🔍 검색 결과 복원: ${_searchResults.length}개');
    }
    
    if (_HomeScreenState._savedSearchQuery != null) {
      _searchController.text = _HomeScreenState._savedSearchQuery!;
      print('🔍 검색어 복원: ${_HomeScreenState._savedSearchQuery}');
    }
    
    if (_HomeScreenState._savedShowSearchResults != null) {
      _showSearchResults = _HomeScreenState._savedShowSearchResults!;
      print('🔍 검색 결과 표시 상태 복원: $_showSearchResults');
    }
  }
  
  void _saveMapState() {
    // 현재 지도 상태 저장
    _HomeScreenState._savedMapLatitude = _centerLatitude;
    _HomeScreenState._savedMapLongitude = _centerLongitude;
    _HomeScreenState._savedSearchResults = List.from(_searchResults);
    _HomeScreenState._savedSearchQuery = _searchController.text;
    _HomeScreenState._savedShowSearchResults = _showSearchResults;
    print('🗺️ 지도 상태 저장: $_centerLatitude, $_centerLongitude, 검색결과 ${_searchResults.length}개');
  }
  
  void _initializeCurrentLocationSync() {
    // 동기 방식으로 캐시된 위치 확인하고 즉시 설정
    final cachedLocation = LocationService.getCachedLocation();
    if (cachedLocation != null) {
      final lat = cachedLocation.latitude!;
      final lng = cachedLocation.longitude!;
      
      // 한국 영토 내인지 확인
      if (lat >= 33.0 && lat <= 43.0 && lng >= 124.0 && lng <= 132.0) {
        _centerLatitude = lat;
        _centerLongitude = lng;
        _isLocationInitialized = true;
        print('📍 캐시된 위치로 즉시 지도 초기화: $lat, $lng');
        // setState는 호출하지 않음 (build가 아직 호출되지 않았으므로)
        return;
      }
    }
    
    // 캐시된 위치가 없으면 기본값으로 시작
    _isLocationInitialized = true;
    print('📍 캐시된 위치 없음, 서울시청으로 시작');
    
    // 백그라운드에서 새로운 위치 가져오기
    _initializeCurrentLocation();
  }
  
  Future<void> _initializeCurrentLocation() async {
    // 백그라운드에서 새로운 GPS 위치 가져오기
    try {
      print('📍 새로운 GPS 위치 가져오는 중...');
      final currentLocation = await LocationService.getCurrentLocation(useCachedFirst: false);
      
      if (currentLocation != null && mounted) {
        final lat = currentLocation.latitude!;
        final lng = currentLocation.longitude!;
        
        // 한국 영토 내인지 확인
        if (lat >= 33.0 && lat <= 43.0 && lng >= 124.0 && lng <= 132.0) {
          print('📍 새로운 GPS 위치 감지: $lat, $lng');
          
          // 현재 중심과 차이가 있으면 이동
          if ((_centerLatitude - lat).abs() > 0.01 || (_centerLongitude - lng).abs() > 0.01) {
            setState(() {
              _centerLatitude = lat;
              _centerLongitude = lng;
            });
            print('📍 지도 중심을 새로운 GPS 위치로 이동: $_centerLatitude, $_centerLongitude');
          } else {
            print('📍 이미 현재 위치 근처에 있음');
          }
        } else {
          print('📍 해외 위치 감지, 서울시청 유지: $lat, $lng');
        }
      } else {
        print('📍 GPS 위치를 가져올 수 없음');
      }
    } catch (e) {
      print('📍 GPS 초기화 실패: $e');
    }
  }

  @override
  void dispose() {
    _saveMapState(); // 위젯 종료 시 지도 상태 저장
    _searchController.dispose();
    _cardScrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  // 외부에서 지도 중심 이동을 위한 함수
  void updateMapCenter(double latitude, double longitude) {
    _webMapKey.currentState?.updateMapCenter(latitude, longitude);
    setState(() {
      _centerLatitude = latitude;
      _centerLongitude = longitude;
    });
  }
  
  // 스크롤 시 중앙 카드 기준으로 지도 이동
  void _onCardScrollChanged() {
    if (_searchResults.isEmpty) return;
    
    final scrollOffset = _cardScrollController.offset;
    final cardWidth = 280.0 + 12.0; // 카드 너비 + 마진
    final centerIndex = (scrollOffset / cardWidth).round();
    
    if (centerIndex >= 0 && centerIndex < _searchResults.length) {
      final centerRestaurant = _searchResults[centerIndex];
      _webMapKey.currentState?.updateMapCenter(
        centerRestaurant.latitude,
        centerRestaurant.longitude,
      );
      setState(() {
        _centerLatitude = centerRestaurant.latitude;
        _centerLongitude = centerRestaurant.longitude;
      });
    }
  }
  
  void _onMarkerClicked(String markerId) {
    try {
      // 식당 마커인지 확인
      if (markerId.startsWith('restaurant_')) {
        final restaurantId = markerId.substring('restaurant_'.length);
        _onRestaurantMarkerClicked(restaurantId);
        return;
      }
      
      // 모임 마커인 경우
      final meeting = widget.meetings.firstWhere(
        (m) => m.id == markerId,
      );
      
      // 동일한 모임이 이미 선택되어 있으면 setState 하지 않음 (지도 재빌드 방지)
      if (_selectedMeeting?.id != meeting.id || !_showBottomCard) {
        setState(() {
          _selectedMeeting = meeting;
          _selectedRestaurant = null; // 식당 선택 해제
          _showBottomCard = true;
          _showSearchResults = false; // 검색 결과 패널 숨기기
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 마커를 찾을 수 없습니다: $markerId');
      }
    }
  }
  
  void _joinMeeting(Meeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });
    
    // 실제 참여 로직은 모임 상세 페이지에서 처리
    Navigator.pushNamed(
      context,
      '/meeting-detail',
      arguments: meeting,
    );
  }
  
  void _goToMeetingDetail(Meeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });
    
    Navigator.pushNamed(
      context,
      '/meeting-detail',
      arguments: meeting,
    ).then((_) {
      // 상세 페이지에서 돌아왔을 때 지도 상태 업데이트
      setState(() {});
    });
  }
  
  void _showMeetingManagement(Meeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });
    
    // 모임 관리 기능 - 모임 상세 페이지로 이동
    Navigator.pushNamed(
      context,
      '/meeting-detail',
      arguments: meeting,
    ).then((_) {
      setState(() {});
    });
  }
  
  void _goToChatRoom(Meeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });
    
    // 채팅방으로 이동
    Navigator.pushNamed(
      context,
      '/chat-room',
      arguments: meeting.id,
    ).then((_) {
      setState(() {});
    });
  }
  
  // 검색 기능
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _showBottomCard = false; // 모임 카드 숨기기
      _selectedMeeting = null;
    });
    
    try {
      print('🔍 검색 시작: "$query"');
      final results = await KakaoSearchService.searchRestaurants(
        query: query,
        size: 10,
        nationwide: true, // 전국 검색으로 변경
      );
      print('🔍 검색 API 응답: ${results.length}개 결과');
      
      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
        
        // 검색 결과가 있으면 가장 가까운 식당(첫 번째 결과)으로 지도 자동 이동
        if (results.isNotEmpty) {
          final closestRestaurant = results.first;
          _centerLatitude = closestRestaurant.latitude;
          _centerLongitude = closestRestaurant.longitude;
          print('📍 가장 가까운 "${closestRestaurant.name}"으로 지도 이동: $_centerLatitude, $_centerLongitude');
        }
      });
      
      // 검색 완료 후 상태 저장
      _saveMapState();
      
      if (kDebugMode) {
        print('✅ 검색 완료: ${results.length}개 결과');
        for (final restaurant in results) {
          print('   - ${restaurant.name} (${restaurant.latitude}, ${restaurant.longitude})');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 검색 실패: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('검색 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  // 식당 마커 클릭
  void _onRestaurantMarkerClicked(String restaurantId) {
    try {
      final restaurant = _searchResults.firstWhere(
        (r) => r.id == restaurantId,
      );
      
      setState(() {
        _selectedRestaurant = restaurant;
        _showBottomCard = true;
        _showSearchResults = false; // 검색 결과 패널 숨기기
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 식당을 찾을 수 없습니다: $restaurantId');
      }
    }
  }
  
  // 검색 리셋 기능
  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _searchResults.clear();
      _showSearchResults = false;
      _showBottomCard = false;
      _selectedRestaurant = null;
      _selectedMeeting = null;
    });
    
    // 상태 저장
    _saveMapState();
    
    if (kDebugMode) {
      print('🔄 검색 리셋됨');
    }
  }
  
  List<MapMarker> _getFilteredMarkers() {
    final markers = <MapMarker>[];
    
    // 기존 모임 마커들 (베이지색)
    final filteredMeetings = widget.meetings.where((meeting) {
      return meeting.latitude != null && meeting.longitude != null;
    }).toList();
    
    markers.addAll(filteredMeetings.map((meeting) => MapMarker(
      id: meeting.id,
      latitude: meeting.latitude!,
      longitude: meeting.longitude!,
      title: '${meeting.restaurantName ?? meeting.location} (${meeting.currentParticipants}/${meeting.maxParticipants})',
      // 기존 모임은 기본 마커 색상 (베이지색)
    )));
    
    // 검색된 식당 마커들 (파란색)
    markers.addAll(_searchResults.map((restaurant) => MapMarker(
      id: 'restaurant_${restaurant.id}',
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      title: restaurant.name,
      color: 'green', // 그린색으로 구분
      rating: restaurant.rating,
    )));
    
    if (kDebugMode) {
      print('🗺️ 생성된 마커들: ${markers.length}개');
      print('   - 모임 마커: ${filteredMeetings.length}개');
      print('   - 검색 결과 마커: ${_searchResults.length}개');
    }
    
    return markers;
  }
  
  List<WebMapMarker> _getFilteredWebMarkers() {
    final markers = <WebMapMarker>[];
    
    // 기존 모임 마커들 (베이지색)
    final filteredMeetings = widget.meetings.where((meeting) {
      return meeting.latitude != null && meeting.longitude != null;
    }).toList();
    
    markers.addAll(filteredMeetings.map((meeting) => WebMapMarker(
      id: meeting.id,
      latitude: meeting.latitude!,
      longitude: meeting.longitude!,
      title: '${meeting.restaurantName ?? meeting.location} (${meeting.currentParticipants}/${meeting.maxParticipants})',
      // 기존 모임은 기본 마커 색상 (베이지색)
    )));
    
    // 검색된 식당 마커들 (파란색)
    markers.addAll(_searchResults.map((restaurant) => WebMapMarker(
      id: 'restaurant_${restaurant.id}',
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      title: restaurant.name,
      color: 'green', // 그린색으로 구분
      rating: restaurant.rating,
    )));
    
    return markers;
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
                  latitude: _centerLatitude,
                  longitude: _centerLongitude,
                  level: 5, // 적절한 범위로 조정 (주변 여러 결과 표시)
                  markers: _getFilteredWebMarkers(),
                )
              : KakaoWebViewMap(
                  key: _webMapKey,
                  latitude: _centerLatitude,
                  longitude: _centerLongitude,
                  level: 5, // 적절한 범위로 조정 (주변 여러 결과 표시)
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
                    prefixIcon: _isSearching 
                        ? Container(
                            width: 20,
                            height: 20,
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.search, color: Colors.grey[600]),
                            onPressed: _performSearch,
                          ),
                    suffixIcon: (_searchController.text.isNotEmpty || _searchResults.isNotEmpty)
                        ? IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                            onPressed: _resetSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _performSearch(),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    // TextField가 변경될 때마다 상태 업데이트 (X 버튼 표시/숨김)
                    setState(() {});
                  },
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 필터 칩들 (두 줄로 배치 - 완전 투명)
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // 첫 번째 줄: 상태 필터
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _statusFilters.length,
                        itemBuilder: (context, index) {
                          final filter = _statusFilters[index];
                          final isSelected = widget.selectedStatusFilter == filter;
                          return _buildMapFilterChip(filter, isSelected, () {
                            widget.onStatusFilterChanged(filter);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 두 번째 줄: 시간 필터
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _timeFilters.length,
                        itemBuilder: (context, index) {
                          final filter = _timeFilters[index];
                          final isSelected = widget.selectedTimeFilter == filter;
                          return _buildMapFilterChip(filter, isSelected, () {
                            widget.onTimeFilterChanged(filter);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
        
        // 현재 위치 버튼 (우측 상단)
        Positioned(
          top: MediaQuery.of(context).padding.top + 140, // 검색바와 두 줄 필터 아래
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
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
                onTap: () async {
                  try {
                    final currentLocation = await LocationService.getCurrentLocation();
                    if (currentLocation != null) {
                      setState(() {
                        _centerLatitude = currentLocation.latitude!;
                        _centerLongitude = currentLocation.longitude!;
                      });
                      _saveMapState(); // 위치 이동 후 상태 저장
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('현재 위치로 이동했습니다'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('위치를 가져올 수 없습니다'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
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
        
        // 검색 리스트 다시보기 버튼 (현재 위치 버튼 아래)
        if (_searchResults.isNotEmpty && !_showSearchResults && _searchController.text.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 200, // 현재 위치 버튼 아래
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    setState(() {
                      _showSearchResults = true;
                      _showBottomCard = false;
                      _selectedMeeting = null;
                      _selectedRestaurant = null;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.list,
                          size: 20,
                          color: Colors.black87,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '리스트',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        
        // 하단 카드 (모임 정보 또는 식당 정보)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showBottomCard ? 16 : -200,
          left: 16,
          right: 16,
          child: _showBottomCard
              ? (_selectedMeeting != null
                  ? _buildMeetingCard(_selectedMeeting!)
                  : _selectedRestaurant != null
                      ? _buildRestaurantCard(_selectedRestaurant!)
                      : const SizedBox.shrink())
              : const SizedBox.shrink(),
        ),
        
        // 검색 결과 패널
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showSearchResults ? 16 : -300,
          left: 16,
          right: 16,
          child: _showSearchResults && _searchResults.isNotEmpty
              ? _buildSearchResultPanel()
              : const SizedBox.shrink(),
        ),
        ],
      ),
    );
  }
  
  Widget _buildMeetingCard(Meeting meeting) {
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
                          meeting.restaurantName ?? meeting.location,
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
                          color: meeting.currentParticipants < meeting.maxParticipants
                              ? const Color(0xFFD2B48C) // 베이지 컬러
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          meeting.currentParticipants < meeting.maxParticipants ? '모집중' : '마감',
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
                        '${meeting.currentParticipants}/${meeting.maxParticipants}명',
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
                          meeting.tags.isNotEmpty ? meeting.tags.first : '일반',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 액션 버튼들 (사용자 상태에 따라 다르게 표시)
                  _buildActionButtons(meeting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButtons(Meeting meeting) {
    final currentUserId = AuthService.currentUserId;
    
    if (currentUserId == null) {
      // 로그인하지 않은 사용자
      return Row(
        children: [
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
        ],
      );
    }
    
    final isHost = meeting.hostId == currentUserId;
    final isParticipant = meeting.participantIds.contains(currentUserId);
    
    if (isHost) {
      // 호스트인 경우
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                _showMeetingManagement(meeting);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2B48C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '모임 관리',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      );
    } else if (isParticipant) {
      // 이미 참석 중인 경우
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                _goToChatRoom(meeting);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2B48C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '채팅하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      );
    } else {
      // 참석하지 않은 경우
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: meeting.currentParticipants < meeting.maxParticipants
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
                meeting.currentParticipants < meeting.maxParticipants ? '참석하기' : '마감',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      );
    }
  }
  
  Widget _buildRestaurantCard(Restaurant restaurant) {
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
            
            // 핸들 바 (중앙)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 식당 정보
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 식당명
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 주소 정보
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
                          restaurant.address,
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
                  
                  const SizedBox(height: 6),
                  
                  // 평점과 카테고리
                  Row(
                    children: [
                      if (restaurant.rating != null && restaurant.rating! > 0) ...[
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.orange[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (restaurant.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            restaurant.category.split('>').last.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 액션 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _createMeetingAtRestaurant(restaurant),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD2B48C), // 베이지색으로 변경
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        '여기서 모임 만들기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
  
  Widget _buildSearchResultPanel() {
    return Container(
      height: 200, // 높이 증가하여 짤림 방지
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
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
          
          // 헤더 (컴팩트)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '검색 결과',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_searchResults.length}개',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSearchResults = false;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // 가로 스크롤 카드 리스트 (카카오맵 스타일)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  _onCardScrollChanged();
                }
                return true;
              },
              child: ListView.builder(
                controller: _cardScrollController,
                scrollDirection: Axis.horizontal, // 가로 스크롤
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final restaurant = _searchResults[index];
                  return _buildSearchResultItem(restaurant);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResultItem(Restaurant restaurant) {
    return GestureDetector(
      onTap: () {
        // 지도 중심을 해당 식당으로 이동
        _moveMapToRestaurant(restaurant);
        // 식당 정보 표시
        _onRestaurantMarkerClicked(restaurant.id);
      },
      child: Container(
        width: 280, // 카드 고정 너비
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 식당명
              Text(
                restaurant.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // 주소
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
                      restaurant.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              if (restaurant.distance != null && restaurant.distance!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      restaurant.formattedDistance,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              
            ],
          ),
        ),
      ),
    );
  }
  
  void _moveMapToRestaurant(Restaurant restaurant) {
    // 지도 중심을 해당 식당으로 이동
    _webMapKey.currentState?.updateMapCenter(
      restaurant.latitude,
      restaurant.longitude,
    );
    // 내부 상태도 업데이트
    setState(() {
      _centerLatitude = restaurant.latitude;
      _centerLongitude = restaurant.longitude;
    });
  }
  
  void _createMeetingAtRestaurant(Restaurant restaurant) {
    setState(() {
      _showBottomCard = false;
      _selectedRestaurant = null;
    });
    
    Navigator.pushNamed(
      context,
      '/create-meeting',
      arguments: {
        'restaurant': restaurant,
        'mapCenter': {
          'latitude': restaurant.latitude,
          'longitude': restaurant.longitude,
        },
      },
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
  
  Widget _buildMapFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.black
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
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
  final VoidCallback? onUnreadCountChanged;
  
  const _ChatListTab({super.key, this.onUnreadCountChanged});

  @override
  State<_ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<_ChatListTab> {
  String? _currentUserId;
  List<Meeting> _participatingMeetings = [];
  Map<String, Message?> _lastMessages = {};
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription<List<Meeting>>? _meetingsSubscription;
  
  // 총 안읽은 메시지 수 계산
  int get totalUnreadCount {
    return _unreadCounts.values.fold(0, (sum, count) => sum + count);
  }

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoadChats();
    _startPeriodicRefresh();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _meetingsSubscription?.cancel();
    super.dispose();
  }
  
  void _startPeriodicRefresh() {
    // 10초마다 채팅 데이터 새로고침
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _loadChatData();
      }
    });
  }

  Future<void> _initializeUserAndLoadChats() async {
    try {
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser != null) {
        _currentUserId = currentFirebaseUser.uid;
        
        // 모임 목록 실시간 구독
        _meetingsSubscription = MeetingService.getMeetingsStream().listen(
          (allMeetings) async {
            final participatingMeetings = allMeetings.where((meeting) {
              return meeting.participantIds.contains(_currentUserId) ||
                     meeting.hostId == _currentUserId;
            }).toList();

            // 날짜순 정렬 (최신순)
            participatingMeetings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

            if (mounted) {
              setState(() {
                _participatingMeetings = participatingMeetings;
              });
              
              // 새로운 모임 목록에 대해 채팅 데이터 로드
              await _loadChatData();
              
              // 부모 위젯에게 안읽은 메시지 수 변경을 알림
              widget.onUnreadCountChanged?.call();
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('❌ 모임 스트림 에러: $error');
            }
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅 목록 초기화 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _loadChatData() async {
    if (_currentUserId == null || _participatingMeetings.isEmpty) return;

    try {
      // 모든 모임의 채팅 데이터를 병렬로 로드
      final futures = _participatingMeetings.map((meeting) async {
        try {
          // 최근 메시지와 안읽은 메시지 수를 병렬로 가져오기
          final results = await Future.wait([
            ChatService.getLatestMessage(meeting.id),
            ChatService.getUnreadMessageCount(meeting.id, _currentUserId!),
          ]);
          
          final lastMessage = results[0] as Message?;
          final unreadCount = results[1] as int;
          
          return {
            'meetingId': meeting.id,
            'lastMessage': lastMessage,
            'unreadCount': unreadCount,
          };
        } catch (e) {
          if (kDebugMode) {
            print('❌ 모임 ${meeting.id} 채팅 데이터 로드 실패: $e');
          }
          return {
            'meetingId': meeting.id,
            'lastMessage': null,
            'unreadCount': 0,
          };
        }
      }).toList();

      final results = await Future.wait(futures);
      
      if (mounted) {
        setState(() {
          for (final result in results) {
            final meetingId = result['meetingId'] as String;
            _lastMessages[meetingId] = result['lastMessage'] as Message?;
            _unreadCounts[meetingId] = result['unreadCount'] as int;
          }
        });
        
        // 부모 위젯에게 안읽은 메시지 수 변경을 알림
        widget.onUnreadCountChanged?.call();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅 데이터 병렬 로드 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_participatingMeetings.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // 채팅방 리스트 (RefreshIndicator 추가)
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadChatData();
            },
            child: ListView.builder(
              itemCount: _participatingMeetings.length,
              itemBuilder: (context, index) {
                final meeting = _participatingMeetings[index];
                return _buildMeetingChatItem(meeting);
              },
            ),
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

  Widget _buildMeetingChatItem(Meeting meeting) {
    final lastMessage = _lastMessages[meeting.id];
    final unreadCount = _unreadCounts[meeting.id] ?? 0;
    final isActive = meeting.dateTime.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChatRoom(meeting),
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
                    color: isActive 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant,
                    color: isActive 
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
                              meeting.restaurantName ?? meeting.location,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessage != null)
                            Text(
                              _formatTime(lastMessage.createdAt),
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
                              lastMessage?.content ?? '채팅을 시작해보세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.outline,
                                fontStyle: lastMessage == null ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
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
                            '${meeting.currentParticipants}명',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (!isActive)
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

  void _openChatRoom(Meeting meeting) async {
    // 채팅방 진입 시 읽음 처리
    await ChatService.markMessagesAsRead(meeting.id, _currentUserId!);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(meeting: meeting),
      ),
    );
    
    // 채팅방에서 돌아온 후 채팅 데이터 새로고침
    await _loadChatData();
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
        final myMeetings = allMeetings.where((meeting) {
          return meeting.participantIds.contains(_currentUserId) || 
                 meeting.hostId == _currentUserId;
        }).toList();

        // 통계 계산
        _participatedMeetings = myMeetings.length;
        _hostedMeetings = myMeetings.where((m) => m.hostId == _currentUserId).length;

        // 예정/완료 모임 분류
        final now = DateTime.now();
        _upcomingMeetings = myMeetings.where((m) => m.dateTime.isAfter(now)).toList();
        _completedMeetings = myMeetings.where((m) => m.dateTime.isBefore(now)).toList();

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
  Widget build(BuildContext context) {
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
          
          // 내 모임 히스토리
          _buildMyMeetingsSection(),
          
          // 설정 메뉴
          _buildSettingsSection(),
          
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
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: _currentUser!.profileImageUrl != null 
                    ? NetworkImage(_currentUser!.profileImageUrl!) 
                    : null,
                child: _currentUser!.profileImageUrl == null
                    ? Text(
                        _currentUser!.name.isNotEmpty ? _currentUser!.name[0] : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatJoinDate(_currentUser!.createdAt)} 가입',
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
          
          // 뱃지들 (실제 활동 기반)
          _buildBadges(),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    final badges = <String>[];
    
    // 활동 기반 뱃지 생성
    if (_participatedMeetings == 0) {
      badges.add('🆕 신규');
    }
    if (_participatedMeetings >= 10) {
      badges.add('🏆 활발한 참여자');
    }
    if (_hostedMeetings >= 5) {
      badges.add('👑 모임 리더');
    }
    if (_currentUser!.rating >= 4.5) {
      badges.add('⭐ 매너왕');
    }
    
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 8,
      children: badges.map((badge) => Container(
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
            ..._upcomingMeetings.take(2).map((meeting) => _buildMeetingItem(meeting)),
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
            ..._completedMeetings.take(2).map((meeting) => _buildMeetingItem(meeting)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMeetingsSection() {
    return Container(
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 모임에 참여해보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingItem(Meeting meeting) {
    final isHost = meeting.hostId == _currentUserId;
    final isUpcoming = meeting.dateTime.isAfter(DateTime.now());
    
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
              color: isHost 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant,
              color: isHost ? Colors.white : Theme.of(context).colorScheme.outline,
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
                      _formatMeetingDate(meeting.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUpcoming
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUpcoming ? '예정' : '완료',
                        style: TextStyle(
                          fontSize: 10,
                          color: isUpcoming
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
          _buildSettingItem(
            Icons.developer_mode,
            '개발자 도구',
            'Firebase 테스트 및 디버깅',
            () => Navigator.pushNamed(context, '/test'),
          ),
          const SizedBox(height: 8),
          _buildSettingItem(
            Icons.logout,
            '로그아웃',
            '',
            () => _showLogoutDialog(),
            isLogout: true,
          ),
          const SizedBox(height: 8),
          _buildSettingItem(
            Icons.delete_forever,
            '회원탈퇴',
            '모든 데이터가 삭제됩니다',
            () => _showDeleteAccountDialog(),
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
            onPressed: () async {
              Navigator.pop(context);
              await _handleLogout();
            },
            child: Text('로그아웃', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('로그아웃 중...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 카카오 로그아웃
      await KakaoAuthService.signOut();
      
      // Firebase 로그아웃
      await AuthService.signOut();

      if (kDebugMode) {
        print('✅ 로그아웃 완료');
      }

      // 로그인 화면으로 이동 (스택 초기화)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 로그아웃 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount();
            },
            child: Text('탈퇴', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    try {
      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('회원탈퇴 처리 중...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 카카오 연결 끊기 + Firebase 계정 삭제
      await KakaoAuthService.unlink();

      if (kDebugMode) {
        print('✅ 회원탈퇴 완료');
      }

      // 로그인 화면으로 이동
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원탈퇴가 완료되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 회원탈퇴 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원탈퇴 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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