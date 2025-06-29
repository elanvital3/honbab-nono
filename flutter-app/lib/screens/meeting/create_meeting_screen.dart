import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting.dart';
import '../../models/restaurant.dart';
import '../../models/user.dart' as app_user;
import '../../components/restaurant_search_modal.dart';
import '../../services/auth_service.dart';
import '../../services/meeting_service.dart';
import '../../services/user_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _maxParticipants = 4;
  String _genderPreference = '무관';
  Restaurant? _selectedRestaurant;
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 기본 설명 텍스트 설정
    _descriptionController.text = '함께 맛있는 식사하실 분 구해요!';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // arguments로 전달된 식당 정보 확인 및 자동 선택
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments['restaurant'] != null && _selectedRestaurant == null) {
      final Restaurant restaurant = arguments['restaurant'] as Restaurant;
      setState(() {
        _selectedRestaurant = restaurant;
        _locationController.text = restaurant.name;
      });
      
      if (kDebugMode) {
        print('✅ 선택된 식당 자동 설정: ${restaurant.name}');
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('ko', 'KR'),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: '시간 선택',
      cancelText: '취소',
      confirmText: '확인',
      hourLabelText: '시간',
      minuteLabelText: '분',
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    
    // 필수 필드 검증
    if (_selectedDate == null || _selectedTime == null) {
      _showErrorSnackBar('날짜와 시간을 모두 선택해주세요');
      return;
    }

    if (_selectedRestaurant == null) {
      _showErrorSnackBar('식당을 선택해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 로그인된 Firebase 사용자 확인
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser == null) {
        _showErrorSnackBar('로그인이 필요합니다');
        return;
      }

      if (kDebugMode) {
        print('🔍 모임 생성 시작 - Firebase UID: ${currentFirebaseUser.uid}');
      }

      // Firestore에서 사용자 정보 가져오기
      final currentUser = await UserService.getUser(currentFirebaseUser.uid);
      if (currentUser == null) {
        _showErrorSnackBar('사용자 정보를 찾을 수 없습니다');
        return;
      }

      if (kDebugMode) {
        print('✅ 사용자 정보 확인: ${currentUser.name}');
        print('🔍 사용자 카카오 ID: ${currentUser.kakaoId}');
      }

      // 모임 날짜/시간 결합
      final meetingDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // 선택된 식당 주소에서 도시 정보 추출
      String city = _extractCityFromAddress(_selectedRestaurant!.address);
      
      // 새 모임 생성
      final newMeeting = Meeting(
        id: '', // MeetingService에서 자동 생성
        description: _descriptionController.text.trim(),
        location: _selectedRestaurant!.name,
        dateTime: meetingDateTime,
        maxParticipants: _maxParticipants,
        currentParticipants: 1,
        hostId: currentUser.id,
        hostName: currentUser.name,
        hostKakaoId: currentUser.kakaoId, // 카카오 ID 저장
        tags: _extractTags(_descriptionController.text),
        participantIds: [currentUser.id],
        latitude: _selectedRestaurant!.latitude,
        longitude: _selectedRestaurant!.longitude,
        restaurantName: _selectedRestaurant!.name,
        genderPreference: _genderPreference,
        city: city, // 도시 정보 추가
        fullAddress: _selectedRestaurant!.address, // 전체 주소 추가
      );

      if (kDebugMode) {
        print('📝 모임 정보:');
        print('  - 식당: ${newMeeting.restaurantName}');
        print('  - 설명: ${newMeeting.description}');
        print('  - 날짜: ${newMeeting.dateTime}');
        print('  - 성별선호: ${newMeeting.genderPreference}');
        print('  - 호스트: ${newMeeting.hostName}');
        print('  - 호스트 카카오 ID: ${newMeeting.hostKakaoId}');
        print('  - 도시: ${newMeeting.city}');
        print('  - 주소: ${newMeeting.fullAddress}');
      }

      // Firestore에 저장
      final createdMeetingId = await MeetingService.createMeeting(newMeeting);
      
      if (kDebugMode) {
        print('✅ 모임 생성 완료 - ID: $createdMeetingId');
      }

      // 호스팅 횟수 증가
      await UserService.incrementHostedMeetings(currentUser.id);

      if (mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('모임이 성공적으로 생성되었습니다! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 홈 화면으로 돌아가기
        Navigator.pop(context);
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 생성 실패: $e');
      }
      
      if (mounted) {
        _showErrorSnackBar('모임 생성 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  List<String> _extractTags(String description) {
    final tags = <String>[];
    if (description.contains('카페') || description.contains('커피')) tags.add('카페');
    if (description.contains('일식') || description.contains('스시') || description.contains('라멘')) tags.add('일식');
    if (description.contains('한식') || description.contains('삼겹살') || description.contains('김치')) tags.add('한식');
    if (description.contains('양식') || description.contains('파스타') || description.contains('피자')) tags.add('양식');
    if (description.contains('중식') || description.contains('짜장면') || description.contains('탕수육')) tags.add('중식');
    if (description.contains('디저트') || description.contains('케이크') || description.contains('아이스크림')) tags.add('디저트');
    if (description.contains('브런치')) tags.add('브런치');
    return tags;
  }

  String _extractCityFromAddress(String address) {
    print('🏙️ 주소에서 도시 추출: "$address"');
    
    // 주소를 공백으로 분리하여 각 부분 검사
    final parts = address.split(' ');
    print('🔍 주소 부분들: $parts');
    
    // 특별시/광역시 처리 ("서울시", "부산시" 등으로 통일)
    for (final part in parts) {
      if (part.contains('특별시') || part.contains('광역시')) {
        String cityName;
        if (part == '서울특별시') cityName = '서울시';
        else if (part == '부산광역시') cityName = '부산시';
        else if (part == '대구광역시') cityName = '대구시';
        else if (part == '인천광역시') cityName = '인천시';
        else if (part == '광주광역시') cityName = '광주시';
        else if (part == '대전광역시') cityName = '대전시';
        else if (part == '울산광역시') cityName = '울산시';
        else if (part == '세종특별자치시') cityName = '세종시';
        else cityName = part.replaceAll('특별시', '시').replaceAll('광역시', '시');
        
        print('✅ 특별시/광역시 도시 추출: "$cityName"');
        return cityName;
      }
    }
    
    // 일반 도 + 시/군 처리
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i].endsWith('도')) {
        final nextPart = parts[i + 1];
        if (nextPart.endsWith('시') || nextPart.endsWith('군')) {
          print('✅ 도 + 시/군 도시 추출: "$nextPart"');
          return nextPart;
        }
      }
    }
    
    // "시"로 끝나는 첫 번째 단어 찾기
    for (final part in parts) {
      if (part.endsWith('시')) {
        print('✅ 시 단위 도시 추출: "$part"');
        return part;
      }
    }
    
    print('❌ 도시 추출 실패, 기타로 설정');
    return '기타';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text('모임 만들기', style: AppTextStyles.titleLarge),
        actions: [
          if (_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          else
            TextButton(
              onPressed: _createMeeting,
              child: Text(
                '완료',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('장소 및 시간'),
              const SizedBox(height: 16),
              
              // 식당 검색 필드
              GestureDetector(
                onTap: _showRestaurantPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedRestaurant == null 
                        ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                        : Theme.of(context).colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_selectedRestaurant != null)
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRestaurant?.name ?? '식당을 검색해주세요',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedRestaurant != null ? FontWeight.w600 : FontWeight.normal,
                                color: _selectedRestaurant == null 
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (_selectedRestaurant != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _selectedRestaurant!.shortCategory,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedRestaurant!.address,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        _selectedRestaurant != null ? Icons.edit : Icons.search,
                        color: _selectedRestaurant != null 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedDate == null
                              ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                              : Theme.of(context).colorScheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? '날짜 선택'
                                  : '${_selectedDate!.month}월 ${_selectedDate!.day}일',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate == null
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedTime == null
                              ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                              : Theme.of(context).colorScheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedTime == null
                                  ? '시간 선택'
                                  : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedTime == null
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle('모집 옵션'),
              const SizedBox(height: 16),
              
              // 최대 인원 설정
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '최대 인원',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _maxParticipants > 2
                          ? () => setState(() => _maxParticipants--)
                          : null,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: _maxParticipants > 2 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_maxParticipants명',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _maxParticipants < 8
                          ? () => setState(() => _maxParticipants++)
                          : null,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: _maxParticipants < 8 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 성별 선호도 설정
              _buildGenderPreferenceSection(),
              const SizedBox(height: 24),
              
              _buildSectionTitle('모임 설명'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: '모임 설명',
                  hintText: '어떤 모임인지 간단히 설명해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '모임 설명을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  void _showRestaurantPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RestaurantSearchModal(
        onRestaurantSelected: (restaurant) {
          setState(() {
            _selectedRestaurant = restaurant;
            _locationController.text = restaurant.name;
          });
        },
      ),
    );
  }

  Widget _buildGenderPreferenceSection() {
    final List<String> genderOptions = ['무관', '동성만', '이성만', '동성 1명이상'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '성별 선호도',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genderOptions.map((option) {
              final isSelected = _genderPreference == option;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _genderPreference = option;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}