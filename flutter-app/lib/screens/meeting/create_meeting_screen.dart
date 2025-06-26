import 'package:flutter/material.dart';
import '../../models/meeting.dart';

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
          const SnackBar(content: Text('날짜와 시간을 모두 선택해주세요')),
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

      final newMeeting = Meeting(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        dateTime: meetingDateTime,
        maxParticipants: _maxParticipants,
        currentParticipants: 1,
        hostName: '나', // TODO: 실제 사용자 이름으로 변경
        tags: _extractTags(_descriptionController.text),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('모임 만들기'),
        actions: [
          TextButton(
            onPressed: _createMeeting,
            child: const Text(
              '완료',
              style: TextStyle(
                color: Colors.white,
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
                decoration: const InputDecoration(
                  labelText: '모임 제목',
                  hintText: '예: 강남 맛집 탐방하실 분!',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: '모임 설명',
                  hintText: '어떤 모임인지 간단히 설명해주세요',
                  border: OutlineInputBorder(),
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
              
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '모임 장소',
                  hintText: '식당 이름 또는 지역을 입력해주세요',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '모임 장소를 입력해주세요';
                  }
                  return null;
                },
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
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? '날짜 선택'
                                  : '${_selectedDate!.month}/${_selectedDate!.day}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time),
                            const SizedBox(width: 8),
                            Text(
                              _selectedTime == null
                                  ? '시간 선택'
                                  : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
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
              
              Row(
                children: [
                  const Text('최대 인원: '),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _maxParticipants > 2
                        ? () => setState(() => _maxParticipants--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_maxParticipants명',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _maxParticipants < 8
                        ? () => setState(() => _maxParticipants++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
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
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}