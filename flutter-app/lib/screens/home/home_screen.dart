import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/meeting.dart';
import '../../models/user.dart';
import '../../components/meeting_card.dart';
import '../../components/kakao_webview_map.dart';
import '../../components/kakao_web_map.dart';
import '../../components/hierarchical_location_picker.dart';
import '../../components/common/common_confirm_dialog.dart';
import '../../components/common/common_loading_dialog.dart';
import '../../components/common/common_card.dart';
import '../../services/meeting_service.dart';
import '../../services/auth_service.dart';
import '../../services/evaluation_service.dart';
import '../../services/user_service.dart';
import '../profile/user_comments_screen.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';
import '../../services/restaurant_service.dart';
import '../../services/google_places_service.dart';
import '../../services/kakao_search_service.dart';
import '../../models/message.dart';
import '../../models/restaurant.dart';
import '../chat/chat_room_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../settings/account_deletion_screen.dart';
import '../../components/participant_profile_widget.dart';
import '../../components/user_badge_chip.dart';
import '../restaurant/restaurant_list_screen.dart';
import '../auth/existing_user_adult_verification_screen.dart';
import '../profile/my_meetings_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey<_ChatListTabState> _chatListKey =
      GlobalKey<_ChatListTabState>();
  final GlobalKey<_MapTabState> _mapKey = GlobalKey<_MapTabState>();
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
        _chatListKey.currentState?.refreshUnreadCounts();
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
  static int? _savedMapLevel;
  static List<Restaurant>? _savedSearchResults;
  static String? _savedSearchQuery;
  static bool? _savedShowSearchResults;

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
        _chatListKey.currentState?.refreshUnreadCounts();
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
                      // 🧪 알림 테스트 섹션
                      Text(
                        '🧪 알림 테스트',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_active,
                          color: Colors.purple,
                        ),
                        title: const Text('📱 채팅 알림 테스트'),
                        subtitle: const Text('테스트 채팅 알림을 생성하고 탭하여 이동 확인'),
                        onTap: () async {
                          Navigator.pop(context);
                          
                          // 알림 서비스 초기화 확인
                          final notificationService = NotificationService();
                          await notificationService.initialize();
                          
                          // 첫 번째 모임 ID 가져오기
                          final meetingsStream = MeetingService.getMeetingsStream();
                          final allMeetings = await meetingsStream.first;
                          if (allMeetings.isNotEmpty) {
                            final testMeeting = allMeetings.first;
                            await notificationService.showTestChatNotification(
                              testMeeting.id,
                              testMeeting.description,
                            );
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🧪 테스트 알림이 생성되었습니다. 알림을 탭해보세요!'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ 테스트할 모임이 없습니다.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.bug_report,
                          color: Colors.green,
                        ),
                        title: const Text('🔔 기본 알림 테스트'),
                        subtitle: const Text('간단한 알림 탭 테스트 (payload: test:simple_test)'),
                        onTap: () async {
                          Navigator.pop(context);
                          
                          // 알림 서비스 초기화 확인
                          final notificationService = NotificationService();
                          await notificationService.initialize();
                          
                          await notificationService.showTestNotification(
                            '🧪 기본 알림 테스트',
                            '알림을 탭하면 로그에 "테스트 알림 탭 감지 성공"이 출력됩니다.',
                          );
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🧪 기본 테스트 알림이 생성되었습니다. 알림을 탭하고 로그를 확인하세요!'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 🗂️ 데이터 삭제 섹션
                      Text(
                        '🗂️ 데이터 삭제',
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
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text('🗑️ 전체 데이터 삭제'),
                        subtitle: const Text('모든 컬렉션의 데이터를 삭제합니다'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _showCleanupConfirmation(context);
                        },
                      ),

                      const Divider(height: 24),

                      // 🏗️ 식당 DB 구축 프로세스
                      Text(
                        '🏗️ 식당 DB 구축 프로세스',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppDesignTokens.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.looks_one,
                          color: Colors.purple,
                        ),
                        title: const Text('1️⃣ 유튜브 맛집 크롤링'),
                        subtitle: const Text('functions/ 스크립트로 기본 식당명 수집'),
                        onTap: () {
                          Navigator.pop(context);
                          _showManualProcessInfo(
                            '1단계: 유튜브 맛집 크롤링',
                            'functions/ 폴더의 크롤링 스크립트를 수동으로 실행하세요:\n\n'
                            '• ultimate_restaurant_crawler.js\n'
                            '• youtube_restaurant_crawler.js\n\n'
                            '이 단계는 Node.js 환경에서 수동으로 실행해야 합니다.',
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.looks_two,
                          color: Colors.blue,
                        ),
                        title: const Text('2️⃣ 카카오 API 정보 매칭'),
                        subtitle: const Text('식당명 → 카카오 ID 기준 상세정보 수집'),
                        onTap: () {
                          Navigator.pop(context);
                          _showManualProcessInfo(
                            '2단계: 카카오 API 정보 매칭',
                            'functions/ 폴더의 스크립트를 수동으로 실행하세요:\n\n'
                            '• restaurant_db_builder.js\n'
                            '• migrate_to_placeid.js\n\n'
                            '카카오 Place ID를 기준키로 설정하고\n'
                            '정확한 주소, 위도/경도, 전화번호 등을 수집합니다.',
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.looks_3,
                          color: Colors.green,
                        ),
                        title: const Text('3️⃣ Google Places 데이터 추가'),
                        subtitle: const Text('사진, 리뷰, 영업시간 등 상세정보 보강'),
                        onTap: () async {
                          Navigator.pop(context);
                          await _runGooglePlacesEnhancement();
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.looks_4,
                          color: Colors.orange,
                        ),
                        title: const Text('4️⃣ 네이버 블로그 데이터 추가'),
                        subtitle: const Text('한국 블로그 리뷰 정보 추가'),
                        onTap: () {
                          Navigator.pop(context);
                          _addNaverBlogDataToAllRestaurants();
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

    // 5. Privacy Consent 컬렉션 정리
    await _cleanupCollection(firestore, 'privacy_consent', '🔒 개인정보 동의');

    print('✅ 테스트 데이터 정리 완료');
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
                _MapTab(
                  key: _mapKey,
                  selectedStatusFilter: _selectedStatusFilter,
                  selectedTimeFilter: _selectedTimeFilter,
                  meetings: filteredMeetings,
                  onStatusFilterChanged: _updateStatusFilter,
                  onTimeFilterChanged: _updateTimeFilter,
                ),
                const RestaurantListScreen(),
                _ChatListTab(
                  key: _chatListKey,
                  // ValueNotifier 방식으로 변경되어 onUnreadCountChanged 콜백 제거
                  // 이제 setState 없이 자동으로 업데이트됨
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

class _MapTabState extends State<_MapTab> with AutomaticKeepAliveClientMixin {
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
    if (_HomeScreenState._savedMapLatitude == null ||
        _HomeScreenState._savedMapLongitude == null) {
      _initializeCurrentLocationSync(); // 동기 방식으로 즉시 위치 설정
    } else {
      print('🗺️ 저장된 지도 상태가 있어 GPS 위치 초기화 건너뜀');
    }
  }

  void _restoreMapState() {
    // 저장된 지도 상태 복원
    if (_HomeScreenState._savedMapLatitude != null &&
        _HomeScreenState._savedMapLongitude != null) {
      _centerLatitude = _HomeScreenState._savedMapLatitude!;
      _centerLongitude = _HomeScreenState._savedMapLongitude!;
      _initialLat = _centerLatitude; // 초기 위치도 복원된 위치로 설정
      _initialLng = _centerLongitude;
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
    _HomeScreenState._savedMapLatitude = _centerLatitude;
    _HomeScreenState._savedMapLongitude = _centerLongitude;
    _HomeScreenState._savedSearchResults = List.from(_searchResults);
    _HomeScreenState._savedSearchQuery = _searchController.text;
    _HomeScreenState._savedShowSearchResults = _showSearchResults;
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
    if (_HomeScreenState._savedMapLatitude != null &&
        _HomeScreenState._savedMapLongitude != null) {
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

class _ChatListTab extends StatefulWidget {
  // onUnreadCountChanged 콜백 제거 - ValueNotifier로 대체

  const _ChatListTab({super.key});

  @override
  State<_ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<_ChatListTab>
    with AutomaticKeepAliveClientMixin {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;
  List<Meeting> _participatingMeetings = [];
  Map<String, Message?> _lastMessages = {};
  // ValueNotifier로 변경 - setState 없이 UI 업데이트
  final Map<String, ValueNotifier<int>> _unreadCountNotifiers = {};
  final ValueNotifier<int> _totalUnreadCountNotifier = ValueNotifier<int>(0);
  bool _isLoading = true;
  StreamSubscription<List<Meeting>>? _meetingsSubscription;
  Map<String, StreamSubscription<Message?>> _messageStreamSubscriptions = {};
  Map<String, StreamSubscription<int>> _unreadCountStreamSubscriptions = {};
  Timer? _updateDebounceTimer; // 디바운스 타이머

  // 참여자 정보 캐시 (participantId -> User)
  final Map<String, User> _participantCache = {};

  // 참여자 정보 로드 (캐시 활용)
  Future<List<User>> _loadParticipants(List<String> participantIds) async {
    final participants = <User>[];

    for (final participantId in participantIds) {
      // 캐시에서 먼저 확인
      if (_participantCache.containsKey(participantId)) {
        participants.add(_participantCache[participantId]!);
        continue;
      }

      // 캐시에 없으면 Firestore에서 로드
      try {
        final user = await UserService.getUser(participantId);
        if (user != null) {
          _participantCache[participantId] = user; // 캐시에 저장
          participants.add(user);
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 참여자 정보 로드 실패: $participantId - $e');
        }
      }
    }

    return participants;
  }

  // 총 안읽은 메시지 수 업데이트 (setState 없음!)
  void _updateTotalUnreadCount() {
    final newTotal = _unreadCountNotifiers.values.fold(
      0,
      (sum, notifier) => sum + notifier.value,
    );
    if (_totalUnreadCountNotifier.value != newTotal) {
      _totalUnreadCountNotifier.value = newTotal; // ValueNotifier 업데이트만!

      // 전역 notifier도 업데이트 (HomeScreen 배지용)
      if (_HomeScreenState.globalUnreadCountNotifier.value != newTotal) {
        _HomeScreenState.globalUnreadCountNotifier.value = newTotal;
      }

      if (kDebugMode) {
        print('📊 총 안읽은 메시지 수: $newTotal (전역 배지 포함)');
      }
    }
  }

  // 외부에서 접근할 수 있는 getter
  int get totalUnreadCount => _totalUnreadCountNotifier.value;

  // 외부에서 ValueNotifier에 접근하기 위한 getter
  ValueNotifier<int> get totalUnreadCountNotifier => _totalUnreadCountNotifier;

  // 스트림 새로고침 메서드 (외부에서 호출 가능)
  void refreshUnreadCounts() {
    if (_currentUserId == null) return;

    if (kDebugMode) {
      print('🔄 안읽은 메시지 카운트 스트림 새로고침 시작');
    }

    // 기존 스트림 정리하고 재설정
    _setupChatStreams();
  }

  // 디바운스된 부모 알림 함수
  void _notifyParentWithDebounce() {
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        // widget.onUnreadCountChanged?.call(); 제거 - ValueNotifier로 대체됨
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoadChats();
  }

  @override
  void dispose() {
    _meetingsSubscription?.cancel();
    _disposeAllChatStreams();
    _updateDebounceTimer?.cancel();

    // ValueNotifier 정리
    for (final notifier in _unreadCountNotifiers.values) {
      notifier.dispose();
    }
    _totalUnreadCountNotifier.dispose();

    super.dispose();
  }

  void _disposeAllChatStreams() {
    for (final subscription in _messageStreamSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _unreadCountStreamSubscriptions.values) {
      subscription.cancel();
    }
    _messageStreamSubscriptions.clear();
    _unreadCountStreamSubscriptions.clear();

    // 기존 notifier들 정리
    for (final notifier in _unreadCountNotifiers.values) {
      notifier.dispose();
    }
    _unreadCountNotifiers.clear();
  }

  void _setupChatStreams() {
    // 기존 스트림 정리
    _disposeAllChatStreams();

    // 각 모임에 대해 실시간 스트림 설정
    for (final meeting in _participatingMeetings) {
      _setupMeetingStreams(meeting.id);
    }

    if (kDebugMode) {
      print('💬 채팅 스트림 설정 완료: ${_participatingMeetings.length}개 모임');
    }
  }

  void _setupMeetingStreams(String meetingId) {
    if (_currentUserId == null) return;

    // 이미 설정된 스트림이 있으면 건너뛰기
    if (_messageStreamSubscriptions.containsKey(meetingId) &&
        _unreadCountStreamSubscriptions.containsKey(meetingId)) {
      return;
    }

    // 최근 메시지 스트림 (에러 처리 및 안전장치 포함)
    _messageStreamSubscriptions[meetingId] = ChatService.getLatestMessageStream(
      meetingId,
    ).listen(
      (message) {
        if (!mounted) return;

        try {
          final previousMessage = _lastMessages[meetingId];
          // 데이터가 실제로 변경된 경우에만 setState
          if (previousMessage?.id != message?.id ||
              previousMessage?.content != message?.content) {
            setState(() {
              _lastMessages[meetingId] = message;
            });
            if (kDebugMode) {
              print('💬 최근 메시지 업데이트: $meetingId');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 메시지 스트림 에러: $e');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ 메시지 스트림 에러: $error');
        }
      },
    );

    // ValueNotifier 생성 (없으면)
    if (!_unreadCountNotifiers.containsKey(meetingId)) {
      _unreadCountNotifiers[meetingId] = ValueNotifier<int>(0);
    }

    // 안읽은 메시지 수 스트림 (setState 없이 ValueNotifier 업데이트)
    _unreadCountStreamSubscriptions[meetingId] =
        ChatService.getUnreadMessageCountStream(
          meetingId,
          _currentUserId!,
        ).listen(
          (count) {
            if (!mounted) return;

            try {
              final currentNotifier = _unreadCountNotifiers[meetingId]!;
              final previousCount = currentNotifier.value;

              // 카운트가 실제로 변경된 경우에만 업데이트 (setState 없음!)
              if (previousCount != count) {
                currentNotifier.value = count; // 이 부분만 리빌드됨!
                _updateTotalUnreadCount(); // 총 개수 업데이트

                // 디바운스된 방식으로 부모에게 알림
                _notifyParentWithDebounce();
                if (kDebugMode) {
                  print('🔢 안읽은 메시지 수 변경: $meetingId -> $count (전체 리빌드 없음!)');
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('❌ 카운트 스트림 에러: $e');
              }
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('❌ 카운트 스트림 에러: $error');
            }
          },
        );
  }

  Future<void> _initializeUserAndLoadChats() async {
    try {
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser != null) {
        _currentUserId = currentFirebaseUser.uid;

        // 즉시 로딩 상태 해제 (빈 상태라도 UI 표시)
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        // 모임 목록 실시간 구독
        _meetingsSubscription = MeetingService.getMeetingsStream().listen(
          (allMeetings) {
            // UID만 사용하여 참여 모임 확인
            final participatingMeetings =
                allMeetings.where((meeting) {
                  return meeting.participantIds.contains(_currentUserId) ||
                      meeting.hostId == _currentUserId;
                }).toList();

            // 날짜순 정렬 (최신순)
            participatingMeetings.sort(
              (a, b) => b.dateTime.compareTo(a.dateTime),
            );

            if (mounted) {
              // 모임 목록이 실제로 변경된 경우에만 업데이트
              final hasChanged =
                  _participatingMeetings.length !=
                      participatingMeetings.length ||
                  !_participatingMeetings.every(
                    (meeting) => participatingMeetings.any(
                      (newMeeting) => newMeeting.id == meeting.id,
                    ),
                  );

              if (hasChanged) {
                setState(() {
                  _participatingMeetings = participatingMeetings;
                  _updateTotalUnreadCount(); // 총 개수 업데이트
                });

                // 새로운 모임 목록에 대해 실시간 스트림 설정
                _setupChatStreams();
                // 디바운스된 방식으로 부모에게 알림
                _notifyParentWithDebounce();

                if (kDebugMode) {
                  print('📱 모임 목록 변경됨: ${participatingMeetings.length}개');
                }
              }
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('❌ 모임 스트림 에러: $error');
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
      } else {
        // 로그인되지 않은 경우 즉시 로딩 해제
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 채팅 목록 초기화 실패: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    if (_participatingMeetings.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // 채팅방 리스트 (RefreshIndicator 추가)
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // 실시간 스트림으로 인해 분사될 필요 없음
              // 스트림이 자동으로 최신 데이터를 제공
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
    final isActive = meeting.dateTime.isAfter(DateTime.now());

    // ValueNotifier 확보
    final unreadCountNotifier =
        _unreadCountNotifiers[meeting.id] ?? ValueNotifier<int>(0);

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
                // 참여자 프로필 사진 (4등분)
                FutureBuilder<List<User>>(
                  future: _loadParticipants(meeting.participantIds),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // 로딩 중 기본 아이콘 표시
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.group,
                          color: Theme.of(context).colorScheme.outline,
                          size: 24,
                        ),
                      );
                    }

                    final participants = snapshot.data ?? [];
                    return ParticipantProfileWidget(
                      participants: participants,
                      currentUserId: _currentUserId ?? '',
                      hostId: meeting.hostId,
                      size: 48,
                    );
                  },
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
                              style: AppTextStyles.titleLarge,
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
                                fontStyle:
                                    lastMessage == null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // ValueListenableBuilder로 배지만 업데이트 (전체 리빌드 없음!)
                          ValueListenableBuilder<int>(
                            valueListenable: unreadCountNotifier,
                            builder: (context, unreadCount, child) {
                              if (unreadCount <= 0)
                                return const SizedBox.shrink();

                              return Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                              );
                            },
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
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
      MaterialPageRoute(builder: (context) => ChatRoomScreen(meeting: meeting)),
    );

    // 실시간 스트림으로 인해 자동 업데이트됨
    // 더 이상 수동 새로고침 불필요
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

class _ProfileTabState extends State<_ProfileTab>
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
          
          // 사업자 정보 섹션
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: AppPadding.all20,
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
                'elanvital3@gmail.com',
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
