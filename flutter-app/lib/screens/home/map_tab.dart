import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import '../../models/meeting.dart';
import '../../models/restaurant.dart';
import '../../components/kakao_webview_map.dart';
import '../../components/kakao_web_map.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/kakao_search_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

// 지도 상태 저장을 위한 static 클래스
class MapTabState {
  static double? _savedMapLatitude;
  static double? _savedMapLongitude;
  static List<Restaurant>? _savedSearchResults;
  static String? _savedSearchQuery;
  static bool? _savedShowSearchResults;

  static double? get savedMapLatitude => _savedMapLatitude;
  static double? get savedMapLongitude => _savedMapLongitude;
  static List<Restaurant>? get savedSearchResults => _savedSearchResults;
  static String? get savedSearchQuery => _savedSearchQuery;
  static bool? get savedShowSearchResults => _savedShowSearchResults;

  static void saveMapState({
    double? latitude,
    double? longitude,
    List<Restaurant>? searchResults,
    String? searchQuery,
    bool? showSearchResults,
  }) {
    _savedMapLatitude = latitude;
    _savedMapLongitude = longitude;
    _savedSearchResults = searchResults;
    _savedSearchQuery = searchQuery;
    _savedShowSearchResults = showSearchResults;
  }

  static void clearMapState() {
    _savedMapLatitude = null;
    _savedMapLongitude = null;
    _savedSearchResults = null;
    _savedSearchQuery = null;
    _savedShowSearchResults = null;
  }
}

class MapTab extends StatefulWidget {
  final String selectedStatusFilter;
  final String selectedTimeFilter;
  final List<Meeting> meetings;
  final Function(String) onStatusFilterChanged;
  final Function(String) onTimeFilterChanged;

  const MapTab({
    super.key,
    required this.selectedStatusFilter,
    required this.selectedTimeFilter,
    required this.meetings,
    required this.onStatusFilterChanged,
    required this.onTimeFilterChanged,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusFilters = ['전체', '모집중', '모집완료'];
  final List<String> _timeFilters = ['오늘', '내일', '일주일', '전체', '지난모임'];
  KakaoMapController? _mapController;

  // 지도 탭 독립적인 필터 상태
  String _localStatusFilter = '전체';
  String _localTimeFilter = '일주일';

  // 즐겨찾기 상태 관리
  final Set<String> _favoriteRestaurants = <String>{};

  // 지도 탭 전용 필터링 함수
  List<Meeting> _filterMapMeetings(List<Meeting> meetings) {
    var filtered = List<Meeting>.from(meetings);
    final now = DateTime.now();

    // 1. 시간 필터 적용
    if (_localTimeFilter == '오늘') {
      filtered =
          filtered.where((meeting) {
            final meetingDate = DateTime(
              meeting.dateTime.year,
              meeting.dateTime.month,
              meeting.dateTime.day,
            );
            final today = DateTime(now.year, now.month, now.day);
            return meetingDate.isAtSameMomentAs(today) &&
                meeting.dateTime.isAfter(now);
          }).toList();
    } else if (_localTimeFilter == '내일') {
      final tomorrow = now.add(const Duration(days: 1));
      filtered =
          filtered.where((meeting) {
            final meetingDate = DateTime(
              meeting.dateTime.year,
              meeting.dateTime.month,
              meeting.dateTime.day,
            );
            final tomorrowDate = DateTime(
              tomorrow.year,
              tomorrow.month,
              tomorrow.day,
            );
            return meetingDate.isAtSameMomentAs(tomorrowDate);
          }).toList();
    } else if (_localTimeFilter == '일주일') {
      final oneWeekLater = now.add(const Duration(days: 7));
      filtered =
          filtered
              .where(
                (meeting) =>
                    meeting.dateTime.isAfter(now) &&
                    meeting.dateTime.isBefore(oneWeekLater),
              )
              .toList();
    } else if (_localTimeFilter == '전체') {
      filtered =
          filtered.where((meeting) => meeting.dateTime.isAfter(now)).toList();
    } else if (_localTimeFilter == '지난모임') {
      // 완료된 모임만 표시 (날짜 무관)
      filtered =
          filtered.where((meeting) => 
            meeting.status == 'completed').toList();
    }

    // 2. 상태 필터 적용 (지난모임일 때는 상태 필터 무시)
    if (_localTimeFilter != '지난모임') {
      if (_localStatusFilter == '모집중') {
        filtered =
            filtered
                .where(
                  (meeting) => meeting.isAvailable && meeting.status == 'active',
                )
                .toList();
      } else if (_localStatusFilter == '모집완료') {
        // 인원이 꽉 찬 활성 모임만 표시 (모임완료된 것 제외)
        filtered =
            filtered.where((meeting) => !meeting.isAvailable && meeting.status == 'active').toList();
      } else if (_localStatusFilter == '전체') {
        // 전체에서는 완료된 모임 제외, 활성 모임만 표시
        filtered =
            filtered.where((meeting) => meeting.status == 'active').toList();
      }
    }

    return filtered;
  }

  final GlobalKey<KakaoWebViewMapState> _webMapKey =
      GlobalKey<KakaoWebViewMapState>();
  final ScrollController _cardScrollController = ScrollController();

  // 하단 카드 관련 상태
  bool _showBottomCard = false;
  Meeting? _selectedMeeting;

  // 지도 중심 좌표 (현재 위치 기반)
  double _centerLatitude = 37.5665; // 기본값: 서울시청
  double _centerLongitude = 126.9780;

  // 재검색 관련 상태
  bool _showReSearchButton = false; // 재검색 버튼 표시 여부
  double _initialLat = 37.5665; // 초기 위도
  double _initialLng = 126.9780; // 초기 경도
  double _currentBoundsSWLat = 0.0; // 현재 경계 남서 위도
  double _currentBoundsSWLng = 0.0; // 현재 경계 남서 경도
  double _currentBoundsNELat = 0.0; // 현재 경계 북동 위도
  double _currentBoundsNELng = 0.0; // 현재 경계 북동 경도
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
    _loadFavorites(); // 즐겨찾기 상태 로드

    // 저장된 지도 상태가 없을 때만 위치 초기화
    if (MapTabState.savedMapLatitude == null ||
        MapTabState.savedMapLongitude == null) {
      _initializeCurrentLocationSync(); // 동기 방식으로 즉시 위치 설정
    } else {
      print('🗺️ 저장된 지도 상태가 있어 GPS 위치 초기화 건너뜀');
    }
  }

  void _restoreMapState() {
    // 저장된 지도 상태 복원
    if (MapTabState.savedMapLatitude != null &&
        MapTabState.savedMapLongitude != null) {
      _centerLatitude = MapTabState.savedMapLatitude!;
      _centerLongitude = MapTabState.savedMapLongitude!;
      _initialLat = _centerLatitude; // 초기 위치도 복원된 위치로 설정
      _initialLng = _centerLongitude;
      print('🗺️ 지도 위치 복원: $_centerLatitude, $_centerLongitude');
    }

    if (MapTabState.savedSearchResults != null) {
      _searchResults = MapTabState.savedSearchResults!;
      print('🔍 검색 결과 복원: ${_searchResults.length}개');
    }

    if (MapTabState.savedSearchQuery != null) {
      _searchController.text = MapTabState.savedSearchQuery!;
      print('🔍 검색어 복원: ${MapTabState.savedSearchQuery}');
    }

    if (MapTabState.savedShowSearchResults != null) {
      _showSearchResults = MapTabState.savedShowSearchResults!;
      print('🔍 검색 결과 표시 상태 복원: $_showSearchResults');
    }
  }

  // 지도 이동 시 호출
  void _onMapMoved(double lat, double lng) {
    // 초기 위치에서 일정 거리 이상 이동했는지 확인
    final distance = _calculateDistance(_initialLat, _initialLng, lat, lng);

    setState(() {
      _centerLatitude = lat;
      _centerLongitude = lng;
    });

    if (distance > 0.5) {
      // 500m 이상 이동 시
      if (!_showReSearchButton) {
        setState(() {
          _showReSearchButton = true;
        });
      }
    }
  }

  // 지도 경계 변경 시 호출
  void _onBoundsChanged(
    double swLat,
    double swLng,
    double neLat,
    double neLng,
  ) {
    _currentBoundsSWLat = swLat;
    _currentBoundsSWLng = swLng;
    _currentBoundsNELat = neLat;
    _currentBoundsNELng = neLng;
  }

  // 두 지점 사이의 거리 계산 (km)
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // 이 지역 재검색
  Future<void> _reSearchInArea() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('검색어를 입력해주세요'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _showReSearchButton = false;
      _initialLat = _centerLatitude;
      _initialLng = _centerLongitude;
      _isSearching = true;
      _showBottomCard = false; // 모임 카드 숨기기
      _selectedMeeting = null;
    });

    try {
      print('🔍 지역 재검색 시작: "$query" (위치: $_centerLatitude, $_centerLongitude)');

      // 현재 지도 중심점에서 식당 재검색
      final results = await KakaoSearchService.searchRestaurantsAtMapCenter(
        query: query,
        latitude: _centerLatitude,
        longitude: _centerLongitude,
        size: 10,
      );

      print('🔍 재검색 API 응답: ${results.length}개 결과');

      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
      });

      // 검색 완료 후 상태 저장
      _saveMapState();

      // 결과 피드백
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            results.isNotEmpty
                ? '이 지역에서 ${results.length}개의 식당을 찾았습니다'
                : '이 지역에서 "$query" 검색 결과가 없습니다',
          ),
          backgroundColor:
              results.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      if (kDebugMode) {
        print('✅ 재검색 완료: ${results.length}개 결과');
        for (final restaurant in results) {
          print(
            '   - ${restaurant.name} (${restaurant.latitude}, ${restaurant.longitude})',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 재검색 실패: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('재검색 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // 현재 보이는 영역의 모임 필터링
  List<Meeting> _getVisibleMeetings() {
    final filteredMeetings = _filterMapMeetings(widget.meetings);

    return filteredMeetings.where((meeting) {
      if (meeting.latitude == null || meeting.longitude == null) return false;

      return meeting.latitude! >= _currentBoundsSWLat &&
          meeting.latitude! <= _currentBoundsNELat &&
          meeting.longitude! >= _currentBoundsSWLng &&
          meeting.longitude! <= _currentBoundsNELng;
    }).toList();
  }

  void _saveMapState() {
    // 현재 지도 상태 저장
    MapTabState.saveMapState(
      latitude: _centerLatitude,
      longitude: _centerLongitude,
      searchResults: List.from(_searchResults),
      searchQuery: _searchController.text,
      showSearchResults: _showSearchResults,
    );
    print(
      '🗺️ 지도 상태 저장: $_centerLatitude, $_centerLongitude, 검색결과 ${_searchResults.length}개',
    );
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
        _initialLat = lat;
        _initialLng = lng;
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
    // 저장된 지도 상태가 있으면 GPS 업데이트 건너뜀
    if (MapTabState.savedMapLatitude != null &&
        MapTabState.savedMapLongitude != null) {
      print('📍 저장된 지도 상태가 있어 GPS 업데이트 건너뜀');
      return;
    }

    // 백그라운드에서 새로운 GPS 위치 가져오기
    try {
      print('📍 새로운 GPS 위치 가져오는 중...');
      final currentLocation = await LocationService.getCurrentLocation(
        useCachedFirst: false,
      );

      if (currentLocation != null && mounted) {
        final lat = currentLocation.latitude!;
        final lng = currentLocation.longitude!;

        // 한국 영토 내인지 확인
        if (lat >= 33.0 && lat <= 43.0 && lng >= 124.0 && lng <= 132.0) {
          print('📍 새로운 GPS 위치 감지: $lat, $lng');

          // 현재 중심과 차이가 있으면 이동
          if ((_centerLatitude - lat).abs() > 0.01 ||
              (_centerLongitude - lng).abs() > 0.01) {
            setState(() {
              _centerLatitude = lat;
              _centerLongitude = lng;
            });
            print(
              '📍 지도 중심을 새로운 GPS 위치로 이동: $_centerLatitude, $_centerLongitude',
            );
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
      final filteredMeetings = _filterMapMeetings(widget.meetings);
      final meeting = filteredMeetings.firstWhere((m) => m.id == markerId);

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
    Navigator.pushNamed(context, '/meeting-detail', arguments: meeting);
  }

  void _goToMeetingDetail(Meeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });

    Navigator.pushNamed(context, '/meeting-detail', arguments: meeting).then((
      _,
    ) {
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
    Navigator.pushNamed(context, '/meeting-detail', arguments: meeting).then((
      _,
    ) {
      setState(() {});
    });
  }

  void _goToChatRoom(Meeting meeting) {
    setState(() {
      _showBottomCard = false;
      _selectedMeeting = null;
    });

    // 채팅방으로 이동
    Navigator.pushNamed(context, '/chat-room', arguments: meeting.id).then((_) {
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
      final results = await KakaoSearchService.searchRestaurantsAtMapCenter(
        query: query,
        latitude: _centerLatitude,
        longitude: _centerLongitude,
        size: 10,
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
          print(
            '📍 가장 가까운 "${closestRestaurant.name}"으로 지도 이동: $_centerLatitude, $_centerLongitude',
          );
        }
      });

      // 검색 완료 후 상태 저장
      _saveMapState();

      if (kDebugMode) {
        print('✅ 검색 완료: ${results.length}개 결과');
        for (final restaurant in results) {
          print(
            '   - ${restaurant.name} (${restaurant.latitude}, ${restaurant.longitude})',
          );
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
      final restaurant = _searchResults.firstWhere((r) => r.id == restaurantId);

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
    final filteredMeetings =
        _filterMapMeetings(widget.meetings).where((meeting) {
          return meeting.latitude != null && meeting.longitude != null;
        }).toList();

    markers.addAll(
      filteredMeetings.map(
        (meeting) => MapMarker(
          id: meeting.id,
          latitude: meeting.latitude!,
          longitude: meeting.longitude!,
          title:
              '${meeting.restaurantName ?? meeting.location} (${meeting.currentParticipants}/${meeting.maxParticipants})',
          // 기존 모임은 기본 마커 색상 (베이지색)
        ),
      ),
    );

    // 검색된 식당 마커들 (파란색)
    markers.addAll(
      _searchResults.map(
        (restaurant) => MapMarker(
          id: 'restaurant_${restaurant.id}',
          latitude: restaurant.latitude,
          longitude: restaurant.longitude,
          title: restaurant.name,
          color: 'green', // 그린색으로 구분
          rating: restaurant.rating,
        ),
      ),
    );

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
    final filteredMeetings =
        _filterMapMeetings(widget.meetings).where((meeting) {
          return meeting.latitude != null && meeting.longitude != null;
        }).toList();

    markers.addAll(
      filteredMeetings.map(
        (meeting) => WebMapMarker(
          id: meeting.id,
          latitude: meeting.latitude!,
          longitude: meeting.longitude!,
          title:
              '${meeting.restaurantName ?? meeting.location} (${meeting.currentParticipants}/${meeting.maxParticipants})',
          // 기존 모임은 기본 마커 색상 (베이지색)
        ),
      ),
    );

    // 검색된 식당 마커들 (파란색)
    markers.addAll(
      _searchResults.map(
        (restaurant) => WebMapMarker(
          id: 'restaurant_${restaurant.id}',
          latitude: restaurant.latitude,
          longitude: restaurant.longitude,
          title: restaurant.name,
          color: 'green', // 그린색으로 구분
          rating: restaurant.rating,
        ),
      ),
    );

    return markers;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        // 터치 시작 시 하단 카드 닫기 (WebView 터치도 감지)
        if (_showBottomCard) {
          // 화면 크기 및 카드 위치 계산
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;

          // 카드는 하단에서 16px 여백으로 positioned되어 있고, 실제 높이는 약 250px
          final cardBottom = screenHeight - 16;
          final cardTop = cardBottom - 250; // 카드 실제 높이
          final cardLeft = 16;
          final cardRight = screenWidth - 16;

          // 카드 영역 밖을 터치했을 때만 닫기
          final isOutsideCard =
              event.position.dy < cardTop ||
              event.position.dy > cardBottom ||
              event.position.dx < cardLeft ||
              event.position.dx > cardRight;

          if (isOutsideCard) {
            setState(() {
              _showBottomCard = false;
              _selectedMeeting = null;
              _selectedRestaurant = null;
            });
          }
        }
      },
      child: Stack(
        children: [
          // 풀스크린 카카오맵 (StatusBar까지)
          Positioned.fill(
            child:
                kIsWeb
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
                      onMapMoved: _onMapMoved,
                      onBoundsChanged: _onBoundsChanged,
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
                        hintText: '지역과 식당이름 검색 (예: 천안 맘스터치)',
                        hintStyle: AppTextStyles.bodyLarge.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        prefixIcon:
                            _isSearching
                                ? Container(
                                  width: 20,
                                  height: 20,
                                  padding: const EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey[600]!,
                                    ),
                                  ),
                                )
                                : IconButton(
                                  icon: Icon(
                                    Icons.search,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: _performSearch,
                                ),
                        suffixIcon:
                            (_searchController.text.isNotEmpty ||
                                    _searchResults.isNotEmpty)
                                ? IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: _resetSearch,
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                              final isSelected = _localStatusFilter == filter;
                              return _buildMapFilterChip(
                                filter,
                                isSelected,
                                () {
                                  setState(() {
                                    _localStatusFilter = filter;
                                  });
                                },
                              );
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
                              final isSelected = _localTimeFilter == filter;
                              return _buildMapFilterChip(
                                filter,
                                isSelected,
                                () {
                                  setState(() {
                                    _localTimeFilter = filter;
                                  });
                                },
                              );
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
                      final currentLocation =
                          await LocationService.getCurrentLocation();
                      if (currentLocation != null) {
                        setState(() {
                          _centerLatitude = currentLocation.latitude!;
                          _centerLongitude = currentLocation.longitude!;
                        });
                        _saveMapState(); // 위치 이동 후 상태 저장
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('현재 위치로 이동했습니다'),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
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

          // 이 지역 재검색 버튼 (현재 위치 버튼 아래) - 검색 후에만 표시
          if (_showReSearchButton && _searchController.text.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 200, // 현재 위치 버튼 아래
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showReSearchButton ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
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
                      borderRadius: BorderRadius.circular(20),
                      onTap: _reSearchInArea,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 18,
                              color: Colors.black87,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '이 지역 재검색',
                              style: TextStyle(
                                fontSize: 13,
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
            ),

          // 검색 리스트 다시보기 버튼 (재검색 버튼 아래)
          if (_searchResults.isNotEmpty &&
              !_showSearchResults &&
              _searchController.text.isNotEmpty)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (_showReSearchButton ? 260 : 200), // 재검색 버튼이 있으면 더 아래로
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list, size: 20, color: Colors.black87),
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
            child:
                _showBottomCard
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
            child:
                _showSearchResults && _searchResults.isNotEmpty
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
              padding: AppPadding.all20,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              meeting.currentParticipants <
                                      meeting.maxParticipants
                                  ? const Color(0xFFD2B48C) // 베이지 컬러
                                  : Colors.grey[400],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          meeting.currentParticipants < meeting.maxParticipants
                              ? '모집중'
                              : '마감',
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
                      Icon(Icons.group, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${meeting.currentParticipants}/${meeting.maxParticipants}명',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              onPressed:
                  meeting.currentParticipants < meeting.maxParticipants
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
                meeting.currentParticipants < meeting.maxParticipants
                    ? '참석하기'
                    : '마감',
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
    return Container(
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
                // 식당명과 즐겨찾기 버튼
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
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
                    _buildFavoriteButton(restaurant),
                  ],
                ),

                const SizedBox(height: 8),

                // 주소 정보
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant.address,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                    if (restaurant.rating != null &&
                        restaurant.rating! > 0) ...[
                      Icon(Icons.star, size: 16, color: Colors.orange[400]),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                Text('검색 결과', style: AppTextStyles.titleLarge),
                const SizedBox(width: 8),
                Text(
                  '${_searchResults.length}개',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSearchResults = false;
                    });
                  },
                  child: Icon(Icons.close, size: 20, color: Colors.grey[600]),
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
                style: AppTextStyles.titleLarge.copyWith(color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 주소
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      restaurant.address,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (restaurant.distance != null &&
                  restaurant.distance!.isNotEmpty) ...[
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: AppPadding.all20,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.3),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
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

  Widget _buildMapFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.7),
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
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 즐겨찾기 상태 로드
  Future<void> _loadFavorites() async {
    try {
      final currentUserId = AuthService.currentUserId;
      if (currentUserId == null) return;

      final user = await UserService.getUser(currentUserId);
      if (user != null) {
        setState(() {
          _favoriteRestaurants.clear();
          _favoriteRestaurants.addAll(user.favoriteRestaurants);
        });
        if (kDebugMode) {
          print('💕 즐겨찾기 로드됨: ${_favoriteRestaurants.length}개');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 로드 실패: $e');
      }
    }
  }

  // 즐겨찾기 토글
  Future<void> _toggleFavorite(Restaurant restaurant) async {
    try {
      final currentUserId = AuthService.currentUserId;
      if (currentUserId == null) {
        if (kDebugMode) {
          print('❌ 즐겨찾기 실패: 로그인되지 않음');
        }
        return;
      }

      if (kDebugMode) {
        print('💕 즐겨찾기 토글 시작: ${restaurant.name} (${restaurant.id})');
        print('💕 사용자 ID: $currentUserId');
      }

      // 새로운 방식: 식당 정보 전체를 저장
      final isFavorite = await RestaurantService.toggleFavoriteWithData(
        restaurant,
      );

      if (kDebugMode) {
        print('💕 즐겨찾기 토글 결과: ${isFavorite ? "추가됨" : "제거됨"}');
      }

      setState(() {
        if (isFavorite) {
          _favoriteRestaurants.add(restaurant.id);
        } else {
          _favoriteRestaurants.remove(restaurant.id);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? '즐겨찾기에 추가되었습니다' : '즐겨찾기에서 제거되었습니다'),
          backgroundColor: isFavorite ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 1),
        ),
      );

      if (kDebugMode) {
        print(
          '${isFavorite ? '💕' : '💔'} ${restaurant.name} 즐겨찾기 ${isFavorite ? '추가' : '제거'}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즐겨찾기 토글 실패: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 즐겨찾기 버튼 위젯
  Widget _buildFavoriteButton(Restaurant restaurant) {
    final isFavorite = _favoriteRestaurants.contains(restaurant.id);

    return AbsorbPointer(
      absorbing: false,
      child: GestureDetector(
        onTap: () {
          if (kDebugMode) {
            print('💕 하트 버튼 클릭됨: ${restaurant.name}');
          }
          _toggleFavorite(restaurant);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isFavorite
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.grey[600],
            size: 20,
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