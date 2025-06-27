import 'package:flutter/material.dart';
import '../../models/meeting.dart';
import '../../models/restaurant.dart';
import '../../components/restaurant_search_modal.dart';
import '../../services/auth_service.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _maxParticipants = 4;
  Restaurant? _selectedRestaurant;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _createMeeting() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('날짜와 시간을 모두 선택해주세요'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        return;
      }

      if (_selectedRestaurant == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('식당을 선택해주세요'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        return;
      }

      final meetingDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final currentUser = AuthService.currentFirebaseUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      final newMeeting = Meeting(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        location: _selectedRestaurant!.name,
        dateTime: meetingDateTime,
        maxParticipants: _maxParticipants,
        currentParticipants: 1,
        hostId: currentUser.uid,
        hostName: currentUser.displayName ?? '익명',
        tags: _extractTags(_descriptionController.text),
        participantIds: [currentUser.uid],
        latitude: _selectedRestaurant!.latitude,
        longitude: _selectedRestaurant!.longitude,
        restaurantName: _selectedRestaurant!.name,
      );

      Navigator.pop(context, newMeeting);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        elevation: 0,
        title: const Text('모임 만들기'),
        actions: [
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
              _buildSectionTitle('모임 정보'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: '모임 제목',
                  hintText: '예: 강남 맛집 탐방하실 분!',
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '모임 제목을 입력해주세요';
                  }
                  return null;
                },
              ),
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
              const SizedBox(height: 24),
              
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
              
              _buildSectionTitle('모집 인원'),
              const SizedBox(height: 16),
              
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
}