import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/meeting.dart';
import '../../components/meeting_card.dart';
import '../../components/hierarchical_location_picker.dart';
import '../../components/common/common_loading_dialog.dart';
import '../../components/common/common_confirm_dialog.dart';
import '../../services/meeting_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../services/restaurant_service.dart';
import '../../services/google_places_service.dart';
import '../../models/restaurant.dart';
import '../restaurant/restaurant_list_screen.dart';
import 'map_tab.dart';
import '../../components/chat_list_tab.dart';
import 'tabs/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey<State<ChatListTab>> _chatListKey =
      GlobalKey<State<ChatListTab>>();
  final GlobalKey<State<MapTab>> _mapKey = GlobalKey<State<MapTab>>();
  // 전역 안읽은 메시지 카운트 관리 (패키지 접근 허용)
  static final ValueNotifier<int> globalUnreadCountNotifier =
      ValueNotifier<int>(0);
  // _totalUnreadCount 제거 - 이제 ValueNotifier로 관리
  // Timer _unreadCountDebounceTimer 제거 - ValueNotifier로 대체됨
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCurrentLocation();
    
    // 알림 클릭으로 인한 네비게이션 처리
    _handlePendingNotification();
    
    // 평가 요청 스트림 구독 (포그라운드에서 즉시 다이얼로그 표시용)
    _listenToEvaluationRequests();
  }
  
  /// 대기 중인 알림 처리
  void _handlePendingNotification() {
    print('🔔 [NOTIFICATION] HomeScreen: _handlePendingNotification 호출됨');
    
    // 앱이 완전히 로드된 후 즉시 처리
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        print('🔔 [NOTIFICATION] HomeScreen: 알림 처리 서비스 호출 (mounted=$mounted)');
        NotificationService().processPendingNotification(context);
      } else {
        print('🔔 [NOTIFICATION] HomeScreen: 위젯이 마운트되지 않아 알림 처리 건너뜀');
      }
    });
  }
  
  /// 평가 요청 스트림 구독 (포그라운드에서 즉시 다이얼로그 표시용)
  void _listenToEvaluationRequests() {
    NotificationService.evaluationRequestStream.listen((meetingId) {
      if (mounted) {
        if (kDebugMode) {
          print('⭐ HomeScreen: 평가 요청 이벤트 수신 - meetingId: $meetingId');
        }
        
        // 짧은 지연 후 처리 (현재 프레임 완료 후)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            NotificationService().processPendingNotification(context);
          }
        });
      }
    }).onError((error) {
      if (kDebugMode) {
        print('❌ HomeScreen: 평가 요청 스트림 에러: $error');
      }
    });
  }
  

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 포어그라운드로 돌아올 때 채팅 스트림 새로고침
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('🔄 앱 포어그라운드 복귀 - 채팅 스트림 새로고침');
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        // ValueNotifier 방식으로 자동 업데이트되므로 수동 호출 불필요
        // _chatListKey.currentState?.refreshUnreadCounts();
      });
      
      // 대기 중인 알림 처리 (백그라운드에서 포그라운드로 복귀 시)
      _handlePendingNotification();
    }
  }

  Future<void> _initializeCurrentLocation() async {
    if (_isLocationInitialized) return;

    try {
      // SharedPreferences에서 먼저 확인
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString('lastKnownCity');

      if (savedCity != null) {
        setState(() {
          _selectedLocationFilter = savedCity;
          _isLocationInitialized = true;
        });
        print('📍 홈화면 지역 필터: 저장된 위치 $savedCity 사용');
        return;
      }

      // 저장된 위치가 없으면 GPS 시도 (빠른 타임아웃)
      final currentLocation = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 2), onTimeout: () => null);

      if (currentLocation != null && mounted) {
        // GPS 위치에서 가장 가까운 도시 찾기
        final nearestCity = LocationService.findNearestCity(
          currentLocation.latitude!,
          currentLocation.longitude!,
        );

        if (nearestCity != null) {
          setState(() {
            _selectedLocationFilter = nearestCity;
            _isLocationInitialized = true;
          });
          // 위치를 SharedPreferences에 저장
          await prefs.setString('lastKnownCity', nearestCity);
          print('📍 홈화면 지역 필터: GPS $nearestCity로 설정하고 저장');
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
  static List<Restaurant>? _savedSearchResults;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 지도 탭으로 이동할 때 상태가 제대로 복원되었는지 확인
    if (index == 1) {
      // 지도 탭
      print('🗺️ 지도 탭 활성화 - 저장된 상태 확인');
      if (_savedMapLatitude != null && _savedMapLongitude != null) {
        print('🗺️ 저장된 지도 위치: $_savedMapLatitude, $_savedMapLongitude');
      }
      if (_savedSearchResults != null) {
        print('🗺️ 저장된 검색 결과: ${_savedSearchResults!.length}개');
      }
    }

    // 채팅 탭으로 이동할 때 안읽은 메시지 카운트 새로고침
    if (index == 2) {
      // 채팅 탭
      if (kDebugMode) {
        print('💬 채팅 탭 활성화 - 안읽은 메시지 카운트 새로고침');
      }
      // 약간의 지연을 두고 새로고침 (탭 전환 완료 후)
      Future.delayed(const Duration(milliseconds: 100), () {
        // ValueNotifier 방식으로 자동 업데이트되므로 수동 호출 불필요
        // _chatListKey.currentState?.refreshUnreadCounts();
      });
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

  // _debounceUnreadCountUpdate 제거 - ValueNotifier로 대체됨

  void _showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: AppPadding.all20,
            child: Column(
              children: [
                Text('개발자 도구', style: AppTextStyles.titleLarge),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      // 🗂️ 데이터 삭제 섹션
                      Text(
                        '🗂️ 데이터 관리',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.orange,
                        ),
                        title: const Text('🍽️ 레스토랑 데이터만 삭제'),
                        subtitle: const Text('restaurants 컬렉션만 삭제합니다'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _showRestaurantCleanupConfirmation(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_sweep,
                          color: Colors.red,
                        ),
                        title: const Text('🗑️ 나머지 컬렉션 삭제'),
                        subtitle: const Text('users, meetings, user_evaluations, messages, privacy_consents,\nmeeting_notifications, meeting_schedules, favorite_restaurants 삭제\n+ Firebase Auth 로그아웃 (restaurants는 유지됨)'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _showCleanupConfirmation(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showCleanupConfirmation(BuildContext context) async {
    final confirmed = await CommonConfirmDialog.showDelete(
      context: context,
      title: '전체 데이터 삭제',
      content:
          '정말로 모든 테스트 데이터를 삭제하시겠습니까?\n\n삭제되는 데이터:\n• 사용자 정보 (users)\n• 모임 정보 (meetings)\n• 사용자 평가 (user_evaluations)\n• 채팅 메시지 (messages)\n• 개인정보 동의 (privacy_consent)\n\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '전체 삭제',
    );

    if (confirmed) {
      await _cleanupAllTestData();
    }
  }

  Future<void> _cleanupAllTestData() async {
    try {
      // 로딩 다이얼로그 표시
      CommonLoadingDialog.show(
        context: context,
        message: '데이터 삭제 중...',
      );

      await _cleanupTestDataCollections();

      if (mounted) {
        CommonLoadingDialog.hide(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 모든 테스트 데이터가 삭제되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CommonLoadingDialog.hide(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 데이터 삭제 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cleanupTestDataCollections() async {
    final firestore = FirebaseFirestore.instance;

    print('🧹 테스트 데이터 정리 시작...');

    // 1. Users 컬렉션 정리
    await _cleanupCollection(firestore, 'users', '👤 사용자');

    // 2. Meetings 컬렉션 정리
    await _cleanupCollection(firestore, 'meetings', '🍽️ 모임');

    // 3. User Evaluations 컬렉션 정리
    await _cleanupCollection(firestore, 'user_evaluations', '⭐ 사용자 평가');

    // 4. Messages 컬렉션 정리
    await _cleanupCollection(firestore, 'messages', '💬 채팅 메시지');

    // 5. Privacy Consents 컬렉션 정리
    await _cleanupCollection(firestore, 'privacy_consents', '🔒 개인정보 동의');

    // 6. Meeting Notifications 컬렉션 정리
    await _cleanupCollection(firestore, 'meeting_notifications', '🔔 모임 알림');

    // 7. Meeting Schedules 컬렉션 정리
    await _cleanupCollection(firestore, 'meeting_schedules', '📅 모임 일정');

    // 8. Favorite Restaurants 컬렉션 정리
    await _cleanupCollection(firestore, 'favorite_restaurants', '⭐ 즐겨찾기 식당');

    // 9. Firebase Auth 사용자 삭제
    await _cleanupFirebaseAuth();

    print('✅ 테스트 데이터 정리 완료');
  }

  Future<void> _cleanupFirebaseAuth() async {
    try {
      print('🔐 Firebase Auth 사용자 정리 시작...');
      
      // 현재 로그인된 사용자가 있으면 계정 삭제
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('  - 현재 사용자 계정 삭제: ${currentUser.uid}');
        try {
          await currentUser.delete();
          print('  - Firebase Auth 계정 삭제 완료');
        } catch (e) {
          print('  - Firebase Auth 계정 삭제 실패: $e');
          // 삭제 실패 시 로그아웃으로 대체
          await FirebaseAuth.instance.signOut();
          print('  - 로그아웃으로 대체 완료');
        }
      }
      
      // 카카오 로그아웃도 함께 처리
      try {
        await KakaoAuthService.signOut();
        print('  - 카카오 로그아웃 완료');
      } catch (e) {
        print('  - 카카오 로그아웃 실패 (무시): $e');
      }
      
      print('✅ Firebase Auth 정리 완료');
    } catch (e) {
      print('❌ Firebase Auth 정리 실패: $e');
    }
  }

  Future<void> _showInvalidRestaurantCleanupConfirmation(
    BuildContext context,
  ) async {
    final confirmed = await CommonConfirmDialog.showDelete(
      context: context,
      title: '잘못된 식당명 정리',
      content:
          '다음 패턴의 잘못된 식당명을 삭제하시겠습니까?\n\n• \"서귀포맛집\", \"제주맛집\" 등 지역+맛집 이름\n• \"현지인맛집\", \"로컬맛집\" 등 일반적인 키워드\n• \"유명맛집\", \"인기맛집\" 등 형용사+맛집\n\n실제 식당 이름은 보존됩니다.',
      confirmText: '정리하기',
    );

    if (confirmed) {
      await _cleanupInvalidRestaurantNames();
    }
  }

  Future<void> _cleanupInvalidRestaurantNames() async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('잘못된 식당명 정리 중...'),
                ],
              ),
            ),
      );

      final firestore = FirebaseFirestore.instance;
      final collection = firestore.collection('restaurants');

      // 잘못된 이름 패턴들
      final invalidPatterns = [
        '맛집',
        '서귀포맛집',
        '제주맛집',
        '제주도맛집',
        '제주시맛집',
        '서울맛집',
        '부산맛집',
        '경주맛집',
        '현지인맛집',
        '로컬맛집',
        '숨은맛집',
        '유명맛집',
        '인기맛집',
        '핫한맛집',
        '대박맛집',
        '찐맛집',
        '진짜맛집',
        '최고맛집',
        '꼭가야할맛집',
        '가성비맛집',
        '베스트맛집',
        '탑텐',
        '순위',
        '랭킹',
      ];

      final querySnapshot = await collection.get();
      int deletedCount = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';

        // 잘못된 패턴과 매칭되는지 확인
        bool shouldDelete = false;
        for (var pattern in invalidPatterns) {
          if (name == pattern ||
              name.contains(pattern) && name.length < 8 ||
              (name.contains('맛집') && name.length < 6)) {
            shouldDelete = true;
            break;
          }
        }

        if (shouldDelete) {
          await doc.reference.delete();
          deletedCount++;
          print('🗑️ 삭제: $name');
        }
      }

      if (mounted) {
        CommonLoadingDialog.hide(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${deletedCount}개의 잘못된 식당명이 정리되었습니다'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CommonLoadingDialog.hide(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 정리 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cleanupCollection(
    FirebaseFirestore firestore,
    String collectionName,
    String displayName,
  ) async {
    try {
      print('🔄 $displayName 컬렉션 정리 중...');

      final querySnapshot = await firestore.collection(collectionName).get();

      if (querySnapshot.docs.isEmpty) {
        print('   ℹ️ $displayName: 삭제할 데이터 없음');
        return;
      }

      // 배치 삭제 (한 번에 최대 500개)
      final batch = firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('   ✅ $displayName: ${querySnapshot.docs.length}개 문서 삭제 완료');
    } catch (e) {
      print('   ❌ $displayName 정리 실패: $e');
      rethrow;
    }
  }

  Future<void> _showRestaurantCleanupConfirmation(BuildContext context) async {
    final confirmed = await CommonConfirmDialog.showDelete(
      context: context,
      title: '레스토랑 데이터 삭제',
      content: '정말로 모든 레스토랑 데이터를 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
    );

    if (confirmed) {
      await _cleanupRestaurantData();
    }
  }

  Future<void> _cleanupRestaurantData() async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('레스토랑 데이터 삭제 중...'),
                ],
              ),
            ),
      );

      final firestore = FirebaseFirestore.instance;
      await _cleanupCollection(firestore, 'restaurants', '🍽️ 레스토랑');

      if (mounted) {
        CommonLoadingDialog.hide(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 모든 레스토랑 데이터가 삭제되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CommonLoadingDialog.hide(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildChatIconWithBadge() {
    // BottomNavigationBar 호환성을 위한 단순한 Badge 위젯 사용
    return ValueListenableBuilder<int>(
      valueListenable: globalUnreadCountNotifier,
      builder: (context, totalUnreadCount, child) {
        if (kDebugMode) {
          print('🔔 채팅 배지 업데이트: $totalUnreadCount');
        }
        // Flutter Badge 위젯 사용 (BottomNavigationBar 안전)
        return Badge(
          isLabelVisible: totalUnreadCount > 0,
          label: Text(
            totalUnreadCount > 99 ? '99+' : '$totalUnreadCount',
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
          child: const Icon(Icons.chat),
        );
      },
    );
  }

  List<Meeting> _filterMeetings(List<Meeting> meetings) {
    if (kDebugMode) {
      print('🔍 필터링 시작: 전체 모임 수: ${meetings.length}');
      print('🔍 현재 필터: 지역=$_selectedLocationFilter, 상태=$_selectedStatusFilter, 시간=$_selectedTimeFilter');
    }
    
    // 1. 시간 필터 적용
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    if (_selectedTimeFilter == '오늘') {
      meetings =
          meetings
              .where(
                (meeting) =>
                    meeting.dateTime.isAfter(today) &&
                    meeting.dateTime.isBefore(tomorrow),
              )
              .toList();
    } else if (_selectedTimeFilter == '내일') {
      meetings =
          meetings
              .where(
                (meeting) =>
                    meeting.dateTime.isAfter(tomorrow) &&
                    meeting.dateTime.isBefore(
                      tomorrow.add(const Duration(days: 1)),
                    ),
              )
              .toList();
    } else if (_selectedTimeFilter == '일주일') {
      meetings =
          meetings
              .where(
                (meeting) =>
                    meeting.dateTime.isAfter(now) &&
                    meeting.dateTime.isBefore(nextWeek),
              )
              .toList();
    } else if (_selectedTimeFilter == '전체') {
      meetings =
          meetings.where((meeting) => meeting.dateTime.isAfter(now)).toList();
    } else if (_selectedTimeFilter == '지난모임') {
      // 완료된 모임만 표시 (날짜 무관)
      meetings =
          meetings.where((meeting) => 
            meeting.status == 'completed').toList();
    }

    // 2. 상태 필터 적용 (지난모임일 때는 상태 필터 무시)
    if (_selectedTimeFilter != '지난모임') {
      if (_selectedStatusFilter == '모집중') {
        meetings =
            meetings
                .where(
                  (meeting) => meeting.isAvailable && meeting.status == 'active',
                )
                .toList();
      } else if (_selectedStatusFilter == '모집완료') {
        // 인원이 꽉 찬 활성 모임만 표시 (모임완료된 것 제외)
        meetings =
            meetings.where((meeting) => !meeting.isAvailable && meeting.status == 'active').toList();
      } else if (_selectedStatusFilter == '전체') {
        // 전체에서는 완료된 모임 제외, 활성 모임만 표시
        meetings =
            meetings.where((meeting) => meeting.status == 'active').toList();
      }
    }

    // 2.5. 지역 필터 적용
    if (_selectedLocationFilter != '전체지역') {
      // 특정 도시 선택 시 해당 도시명으로 필터링 (더 유연한 매칭)
      final filterKeyword = _selectedLocationFilter.replaceAll('시', '').replaceAll('도', '');
      
      if (kDebugMode) {
        print('🔍 지역 필터링: $_selectedLocationFilter -> 키워드: $filterKeyword');
        print('🔍 필터링 전 모임 수: ${meetings.length}');
      }
      
      meetings =
          meetings
              .where(
                (meeting) {
                  if (kDebugMode) {
                    print('🔍 모임 체크: ${meeting.description}');
                    print('   - city: ${meeting.city}');
                    print('   - location: ${meeting.location}');
                    print('   - fullAddress: ${meeting.fullAddress}');
                    print('   - restaurantName: ${meeting.restaurantName}');
                  }
                  // city 필드 확인
                  if (meeting.city != null && 
                      (meeting.city!.contains(filterKeyword) || 
                       meeting.city! == _selectedLocationFilter)) {
                    return true;
                  }
                  
                  // location 필드 확인 (더 유연한 매칭)
                  if (meeting.location.contains(filterKeyword) ||
                      meeting.location.contains(_selectedLocationFilter)) {
                    return true;
                  }
                  
                  // fullAddress 필드 확인
                  if (meeting.fullAddress != null &&
                      (meeting.fullAddress!.contains(filterKeyword) ||
                       meeting.fullAddress!.contains(_selectedLocationFilter))) {
                    return true;
                  }
                  
                  // restaurantName 확인
                  if (meeting.restaurantName != null &&
                      (meeting.restaurantName!.contains(filterKeyword) ||
                       meeting.restaurantName!.contains(_selectedLocationFilter))) {
                    return true;
                  }
                  
                  return false;
                },
              )
              .toList();
              
      if (kDebugMode) {
        print('🔍 지역 필터링 후 모임 수: ${meetings.length}');
      }
    }
    // '전체지역'만 모든 모임 표시

    // 3. 검색어 필터 적용
    if (_searchQuery.isNotEmpty) {
      meetings =
          meetings.where((meeting) {
            return (meeting.restaurantName?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                meeting.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                meeting.location.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                meeting.tags.any(
                  (tag) =>
                      tag.toLowerCase().contains(_searchQuery.toLowerCase()),
                );
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

    if (kDebugMode) {
      print('🔍 최종 필터링 결과: ${meetings.length}개 모임');
    }

    return meetings;
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 핸들
                Container(
                  margin: const EdgeInsets.only(top: AppDesignTokens.spacing3),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 헤더
                Padding(
                  padding: AppPadding.all20,
                  child: Row(
                    children: [
                      Text(
                        '지역 선택',
                        style: AppTextStyles.headlineMedium.copyWith(
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
                            padding: AppPadding.all16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color:
                                  _selectedLocationFilter == '전체지역'
                                      ? Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  color:
                                      _selectedLocationFilter == '전체지역'
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '전체지역',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color:
                                          _selectedLocationFilter == '전체지역'
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      fontWeight:
                                          _selectedLocationFilter == '전체지역'
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (_selectedLocationFilter == '전체지역')
                                  Icon(
                                    Icons.check,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                              final currentLocation =
                                  await LocationService.getCurrentLocation();
                              if (currentLocation != null) {
                                final nearestCity =
                                    LocationService.findNearestCity(
                                      currentLocation.latitude!,
                                      currentLocation.longitude!,
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
                            padding: AppPadding.all16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.transparent,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.2),
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
                                    style: AppTextStyles.bodyLarge,
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
                        initialCity:
                            _selectedLocationFilter == '전체지역'
                                ? null
                                : _selectedLocationFilter,
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
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    // _unreadCountDebounceTimer?.cancel(); 제거
    super.dispose();
  }

  // 뒤로가기 처리 함수
  Future<bool> _handleBackPress() async {
    // 홈 탭이 아닌 경우 홈 탭으로 이동
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false; // 앱 종료하지 않음
    }

    // 홈 탭에서 뒤로가기 시 종료 확인
    final shouldExit = await CommonConfirmDialog.show(
      context: context,
      title: '앱 종료',
      content: '혼밥노노를 종료하시겠습니까?',
      cancelText: '취소',
      confirmText: '종료',
      confirmTextColor: Colors.red[400],
    );

    if (shouldExit) {
      // 앱을 완전히 종료
      SystemNavigator.pop();
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 항상 뒤로가기 처리 함수를 통해 처리
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // _handleBackPress()에서 SystemNavigator.pop() 호출하므로
          // 별도의 Navigator.pop() 호출 불필요
          await _handleBackPress();
        }
      },
      child: StreamBuilder<List<Meeting>>(
        stream: MeetingService.getMeetingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            // 에러 로깅 추가
            if (kDebugMode) {
              print('❌ HomeScreen StreamBuilder 에러: ${snapshot.error}');
              print('❌ 에러 스택 트레이스: ${snapshot.stackTrace}');
            }

            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text('데이터를 불러오는 중 오류가 발생했습니다.'),
                    const SizedBox(height: 8),
                    if (kDebugMode) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '에러: ${snapshot.error}',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
            appBar:
                _selectedIndex == 1
                    ? null
                    : AppBar(
                      // 지도 탭일 때 앱바 숨김
                      backgroundColor: AppDesignTokens.background,
                      foregroundColor: AppDesignTokens.onSurface,
                      elevation: 0,
                      title:
                          _selectedIndex == 0
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
                                        const SizedBox(
                                          width: AppDesignTokens.spacing1,
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color: AppDesignTokens.onSurface,
                                          size: AppDesignTokens.iconDefault,
                                        ),
                                      ],
                                    ),
                                  ))
                              : Text(
                                _selectedIndex == 2
                                    ? '여행맛집'
                                    : _selectedIndex == 3
                                    ? '채팅'
                                    : _selectedIndex == 4
                                    ? '마이페이지'
                                    : '혼뱁노노',
                                style: AppTextStyles.headlineMedium,
                              ),
                      actions: [
                        if (_selectedIndex == 0)
                          IconButton(
                            icon: Icon(
                              _searchQuery.isEmpty ? Icons.search : Icons.close,
                            ),
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
                        // 디버그 모드에서만 FCM 테스트 버튼 표시
                        if (kDebugMode)
                          IconButton(
                            icon: const Icon(
                              Icons.bug_report,
                              color: Colors.red,
                            ),
                            tooltip: '디버그 테스트 메뉴',
                            onPressed: () {
                              _showDebugMenu(context);
                            },
                          ),
                      ],
                    ),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeTabWithSubTabs(
                  meetings: filteredMeetings,
                  allMeetings: allMeetings, // 지역 필터링 안된 전체 모임 (내모임용)
                  selectedStatusFilter: _selectedStatusFilter,
                  selectedTimeFilter: _selectedTimeFilter,
                  selectedLocationFilter: _selectedLocationFilter,
                  onStatusFilterChanged: _updateStatusFilter,
                  onTimeFilterChanged: _updateTimeFilter,
                  onLocationFilterChanged: _updateLocationFilter,
                ),
                MapTab(
                  key: _mapKey,
                  selectedStatusFilter: _selectedStatusFilter,
                  selectedTimeFilter: _selectedTimeFilter,
                  meetings: filteredMeetings,
                  onStatusFilterChanged: _updateStatusFilter,
                  onTimeFilterChanged: _updateTimeFilter,
                ),
                const RestaurantListScreen(),
                ChatListTab(
                  key: _chatListKey,
                  onUnreadCountChanged: (count) {
                    globalUnreadCountNotifier.value = count;
                  },
                ),
                const ProfileTab(),
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
              elevation: 0, // 그림자 제거
              backgroundColor: AppDesignTokens.surface, // 배경색 명시
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: '홈',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: '지도',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_menu),
                  label: '여행맛집',
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
            floatingActionButton:
                _selectedIndex == 0
                    ? FloatingActionButton.extended(
                      heroTag: "home_create_fab",
                      onPressed: () async {
                        if (AuthService.currentUserId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그인이 필요합니다.')),
                          );
                          return;
                        }

                        // 본인인증 체크
                        try {
                          final currentUserId = AuthService.currentUserId;
                          if (currentUserId == null) return;
                          
                          final currentUser = await UserService.getUser(currentUserId);
                          if (currentUser == null) return;

                          if (!currentUser.isAdultVerified) {
                            // 본인인증이 안된 경우 다이얼로그 표시
                            showDialog(
                              context: context,
                              builder: (context) => const CommonConfirmDialog(
                                title: '본인인증이 필요합니다',
                                content: '모임을 주최하려면 본인인증을 완료해야 합니다. 마이페이지에서 본인인증을 진행해주세요.',
                                confirmText: '확인',
                                icon: Icons.verified_user,
                                showCancelButton: false,
                              ),
                            );
                            return;
                          }

                          // 본인인증이 완료된 경우에만 모임 생성 화면으로 이동
                          final result = await Navigator.pushNamed(
                            context,
                            '/create-meeting',
                          );
                          // CreateMeetingScreen에서 이미 모임을 생성하고 성공 메시지도 표시했으므로
                          // 여기서는 추가 처리가 필요없음 (StreamBuilder가 자동으로 새 데이터를 받아옴)
                        } catch (e) {
                          if (kDebugMode) {
                            print('❌ 사용자 정보 확인 실패: $e');
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('사용자 정보를 확인할 수 없습니다.')),
                          );
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        '모임 만들기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    : null,
          );
        },
      ),
    );
  }

  /// 🧪 Google Places API 테스트 (데이터 확인만, 저장 안함)
  Future<void> _runGooglePlacesTest() async {
    if (kDebugMode) {
      print('\n🚀 Google Places 테스트 시작...');
      
      // 사용자에게 테스트 시작 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧪 Google Places 테스트 시작 (콘솔 확인)'),
          backgroundColor: Colors.blue,
        ),
      );

      try {
        // 1. API 키 테스트
        print('\n--- 1. API 키 테스트 ---');
        final isApiValid = await GooglePlacesService.testApiKey();
        
        if (isApiValid) {
          // 2. 지역별 샘플링 테스트
          print('\n--- 2. 지역별 샘플링 테스트 ---');
          await GooglePlacesService.testRegionSampling();
          
          // 3. 서울 상세 테스트
          print('\n--- 3. 서울 상세 테스트 ---');
          await GooglePlacesService.testSingleRegionDetail('서울');
          
          // 테스트 완료 알림
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Google Places 테스트 완료 (콘솔 확인)'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Google Places API 키가 유효하지 않습니다'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Google Places 테스트 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ 테스트 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showManualProcessInfo(String title, String description) {
    CommonConfirmDialog.show(
      context: context,
      title: title,
      content: description,
      confirmText: '확인',
      showCancelButton: false,
    );
  }

  Future<void> _runGooglePlacesEnhancement() async {
    // 확인 다이얼로그 표시
    final shouldProceed = await CommonConfirmDialog.show(
      context: context,
      title: 'Google Places 데이터 추가',
      content: '기존 레스토랑 데이터에 Google Places 정보를 추가합니다:\n\n'
          '• 사진 (최대 10장)\n'
          '• 상세 영업시간\n'
          '• 별점 및 리뷰 수\n\n'
          '이 작업은 시간이 오래 걸릴 수 있습니다.\n\n'
          '계속하시겠습니까?',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (!shouldProceed) return;

    // 실제 Google Places 테스트 실행
    await _runGooglePlacesTest();
  }

  void _addNaverBlogDataToAllRestaurants() async {
    // 확인 다이얼로그 표시
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('네이버 블로그 데이터 추가'),
        content: const Text(
          'DB에 저장된 모든 식당들에 네이버 블로그 정보를 추가합니다.\n'
          '이 작업은 시간이 오래 걸릴 수 있습니다.\n\n'
          '계속하시겠습니까?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('네이버 블로그 데이터를 추가하는 중...'),
          ],
        ),
      ),
    );

    try {
      // 네이버 블로그 데이터 추가 실행
      final result = await RestaurantService.addNaverBlogDataToAllRestaurants();
      
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      // 결과 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('네이버 블로그 데이터 추가 완료'),
            content: Text(
              '총 ${result['total']}개 식당 중:\n'
              '✅ 성공: ${result['success']}개\n'
              '❌ 실패: ${result['failed']}개\n'
              '⏭️ 기존보유: ${result['alreadyHas']}개'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      // 에러 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류'),
            content: Text('네이버 블로그 데이터 추가 중 오류가 발생했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _addYoutubeDataToAllRestaurants() async {
    // 확인 다이얼로그 표시
    final shouldProceed = await CommonConfirmDialog.show(
      context: context,
      title: '유튜브 데이터 추가',
      content: 'DB에 저장된 모든 식당들에 유튜브 정보를 추가합니다.\n'
          '이 작업은 시간이 오래 걸릴 수 있습니다.\n\n'
          '계속하시겠습니까?',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (!shouldProceed) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('유튜브 데이터를 추가하는 중...'),
          ],
        ),
      ),
    );

    try {
      // 유튜브 데이터 추가 실행
      final result = await RestaurantService.addYoutubeDataToAllRestaurants();
      
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      // 결과 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('유튜브 데이터 추가 완료'),
            content: Text(
              '총 ${result['total']}개 식당 중:\n'
              '✅ 성공: ${result['success']}개\n'
              '❌ 실패: ${result['failed']}개\n'
              '⏭️ 기존보유: ${result['alreadyHas']}개'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      // 에러 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류'),
            content: Text('유튜브 데이터 추가 중 오류가 발생했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _HomeTabWithSubTabs({
    required List<Meeting> meetings,
    required List<Meeting> allMeetings,
    required String selectedStatusFilter,
    required String selectedTimeFilter,
    required String selectedLocationFilter,
    required Function(String) onStatusFilterChanged,
    required Function(String) onTimeFilterChanged,
    required Function(String) onLocationFilterChanged,
  }) {
    return _MeetingListTab(
      meetings: meetings,
      selectedStatusFilter: selectedStatusFilter,
      selectedTimeFilter: selectedTimeFilter,
      selectedLocationFilter: selectedLocationFilter,
      onStatusFilterChanged: onStatusFilterChanged,
      onTimeFilterChanged: onTimeFilterChanged,
      onLocationFilterChanged: onLocationFilterChanged,
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

class _MeetingListTabState extends State<_MeetingListTab>
    with AutomaticKeepAliveClientMixin {
  final List<String> _statusFilters = ['전체', '모집중', '모집완료'];
  final List<String> _timeFilters = ['오늘', '내일', '일주일', '전체', '지난모임'];
  final List<String> _locationFilters = [
    '전체',
    '서울시 중구',
    '서울시 강남구',
    '서울시 마포구',
    '서울시 성동구',
    '서울시 용산구',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return Column(
      children: [
        // 필터 칩들 (두 줄로 배치)
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppDesignTokens.spacing1, horizontal: AppDesignTokens.spacing4),
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
                    ..._statusFilters.map(
                      (filter) => _buildFilterChip(
                        filter,
                        widget.selectedStatusFilter == filter,
                        () => widget.onStatusFilterChanged(filter),
                      ),
                    ),
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
                    ..._timeFilters.map(
                      (filter) => _buildFilterChip(
                        filter,
                        widget.selectedTimeFilter == filter,
                        () => widget.onTimeFilterChanged(filter),
                      ),
                    ),
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
            child:
                widget.meetings.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '조건에 맞는 모임이 없어요',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '다른 필터를 선택하거나 첫 모임을 만들어보세요!',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: AppPadding.vertical8,
                      itemCount: widget.meetings.length,
                      itemBuilder: (context, index) {
                        final meeting = widget.meetings[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          curve: Curves.easeOutBack,
                          child: MeetingCard(
                            meeting: meeting,
                            currentUserId: AuthService.currentUserId,
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
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
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

  Widget _buildMapFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
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
}



