import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting.dart';
import '../../services/meeting_service.dart';

class EditMeetingScreen extends StatefulWidget {
  final Meeting meeting;

  const EditMeetingScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<EditMeetingScreen> createState() => _EditMeetingScreenState();
}

class _EditMeetingScreenState extends State<EditMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  DateTime _selectedDateTime = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 기존 모임 정보로 초기화
    _descriptionController.text = widget.meeting.description;
    _maxParticipantsController.text = widget.meeting.maxParticipants.toString();
    _selectedDateTime = widget.meeting.dateTime;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _updateMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    final maxParticipants = int.tryParse(_maxParticipantsController.text);
    if (maxParticipants == null || maxParticipants < widget.meeting.currentParticipants) {
      _showErrorMessage('최대 인원은 현재 참여자 수(${widget.meeting.currentParticipants}명)보다 많아야 합니다');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedMeeting = widget.meeting.copyWith(
        description: _descriptionController.text.trim(),
        dateTime: _selectedDateTime,
        maxParticipants: maxParticipants,
        updatedAt: DateTime.now(),
      );

      await MeetingService.updateMeetingFromModel(updatedMeeting);

      if (mounted) {
        Navigator.pop(context, true); // 수정 완료 신호 전달
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모임이 성공적으로 수정되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 수정 실패: $e');
      }
      _showErrorMessage('모임 수정에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        title: const Text('모임 수정'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateMeeting,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '저장',
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 모임 설명
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '모임 설명',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: '어떤 모임인지 설명해주세요',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '모임 설명을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 모임 날짜/시간
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '모임 날짜/시간',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateTime,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_selectedDateTime.year}년 ${_selectedDateTime.month}월 ${_selectedDateTime.day}일 '
                              '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 최대 인원
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '최대 인원',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '현재 참여자: ${widget.meeting.currentParticipants}명',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxParticipantsController,
                      decoration: const InputDecoration(
                        hintText: '최대 인원을 입력하세요',
                        border: OutlineInputBorder(),
                        suffixText: '명',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '최대 인원을 입력해주세요';
                        }
                        final number = int.tryParse(value);
                        if (number == null || number < 2 || number > 20) {
                          return '최대 인원은 2~20명 사이로 입력해주세요';
                        }
                        if (number < widget.meeting.currentParticipants) {
                          return '현재 참여자 수보다 적을 수 없습니다';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 수정 불가 정보
            Card(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '수정 불가 정보',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField('위치', widget.meeting.restaurantName ?? widget.meeting.location),
                    _buildReadOnlyField('호스트', widget.meeting.hostName),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}