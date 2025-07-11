import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // 푸시 알림 설정
  bool _newMeetingNotification = true;
  bool _chatNotification = true;
  bool _meetingReminderNotification = true;
  bool _participantNotification = true;
  bool _favoriteRestaurantNotification = true;
  
  
  // 방해금지 모드
  bool _doNotDisturbEnabled = false;
  TimeOfDay _doNotDisturbStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _doNotDisturbEnd = const TimeOfDay(hour: 8, minute: 0);
  
  // 리마인더 시간
  int _reminderMinutes = 60; // 기본 1시간 전
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _newMeetingNotification = prefs.getBool('newMeetingNotification') ?? true;
      _chatNotification = prefs.getBool('chatNotification') ?? true;
      _meetingReminderNotification = prefs.getBool('meetingReminderNotification') ?? true;
      _participantNotification = prefs.getBool('participantNotification') ?? true;
      _favoriteRestaurantNotification = prefs.getBool('favoriteRestaurantNotification') ?? true;
      _doNotDisturbEnabled = prefs.getBool('doNotDisturbEnabled') ?? false;
      _reminderMinutes = prefs.getInt('reminderMinutes') ?? 60;
      
      // 방해금지 시간 로드
      final startHour = prefs.getInt('doNotDisturbStartHour') ?? 22;
      final startMinute = prefs.getInt('doNotDisturbStartMinute') ?? 0;
      final endHour = prefs.getInt('doNotDisturbEndHour') ?? 8;
      final endMinute = prefs.getInt('doNotDisturbEndMinute') ?? 0;
      
      _doNotDisturbStart = TimeOfDay(hour: startHour, minute: startMinute);
      _doNotDisturbEnd = TimeOfDay(hour: endHour, minute: endMinute);
      
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('newMeetingNotification', _newMeetingNotification);
    await prefs.setBool('chatNotification', _chatNotification);
    await prefs.setBool('meetingReminderNotification', _meetingReminderNotification);
    await prefs.setBool('participantNotification', _participantNotification);
    await prefs.setBool('favoriteRestaurantNotification', _favoriteRestaurantNotification);
    await prefs.setBool('doNotDisturbEnabled', _doNotDisturbEnabled);
    await prefs.setInt('reminderMinutes', _reminderMinutes);
    
    // 방해금지 시간 저장
    await prefs.setInt('doNotDisturbStartHour', _doNotDisturbStart.hour);
    await prefs.setInt('doNotDisturbStartMinute', _doNotDisturbStart.minute);
    await prefs.setInt('doNotDisturbEndHour', _doNotDisturbEnd.hour);
    await prefs.setInt('doNotDisturbEndMinute', _doNotDisturbEnd.minute);
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _doNotDisturbStart : _doNotDisturbEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppDesignTokens.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _doNotDisturbStart = picked;
        } else {
          _doNotDisturbEnd = picked;
        }
      });
      _saveSettings();
    }
  }

  void _showReminderTimeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리마인더 시간'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('30분 전'),
              value: 30,
              groupValue: _reminderMinutes,
              activeColor: AppDesignTokens.primary,
              onChanged: (value) {
                setState(() => _reminderMinutes = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('1시간 전'),
              value: 60,
              groupValue: _reminderMinutes,
              activeColor: AppDesignTokens.primary,
              onChanged: (value) {
                setState(() => _reminderMinutes = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('2시간 전'),
              value: 120,
              groupValue: _reminderMinutes,
              activeColor: AppDesignTokens.primary,
              onChanged: (value) {
                setState(() => _reminderMinutes = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('하루 전'),
              value: 1440,
              groupValue: _reminderMinutes,
              activeColor: AppDesignTokens.primary,
              onChanged: (value) {
                setState(() => _reminderMinutes = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getReminderText() {
    if (_reminderMinutes == 30) return '30분 전';
    if (_reminderMinutes == 60) return '1시간 전';
    if (_reminderMinutes == 120) return '2시간 전';
    if (_reminderMinutes == 1440) return '하루 전';
    return '$_reminderMinutes분 전';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppDesignTokens.background,
          foregroundColor: AppDesignTokens.onSurface,
          elevation: 0,
          title: Text('알림 설정', style: AppTextStyles.titleLarge),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text('알림 설정', style: AppTextStyles.titleLarge),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 푸시 알림 섹션
            _buildPushNotificationSection(),
            
            const SizedBox(height: AppDesignTokens.spacing3),
            
            // 방해금지 모드 섹션
            _buildDoNotDisturbSection(),
            
            const SizedBox(height: AppDesignTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildPushNotificationSection() {
    return CommonCard(
      margin: AppPadding.all16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '푸시 알림',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          
          _buildSwitchTile(
            '새 모임 알림',
            '내 근처 5km 이내에 새로운 모임이 생성될 때 알림을 받습니다',
            _newMeetingNotification,
            (value) {
              setState(() => _newMeetingNotification = value);
              _saveSettings();
            },
          ),
          
          _buildSwitchTile(
            '채팅 메시지',
            '참여한 모임의 새 메시지가 있을 때 알림을 받습니다',
            _chatNotification,
            (value) {
              setState(() => _chatNotification = value);
              _saveSettings();
            },
          ),
          
          _buildSwitchTile(
            '모임 리마인더',
            '참여한 모임 시작 전에 미리 알림을 받습니다',
            _meetingReminderNotification,
            (value) {
              setState(() => _meetingReminderNotification = value);
              _saveSettings();
            },
          ),
          
          if (_meetingReminderNotification) ...[
            const SizedBox(height: AppDesignTokens.spacing2),
            InkWell(
              onTap: _showReminderTimeDialog,
              borderRadius: AppBorderRadius.medium,
              child: Container(
                padding: AppPadding.all12,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: AppBorderRadius.medium,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: AppDesignTokens.spacing3),
                    Expanded(
                      child: Text(
                        '리마인더 시간: ${_getReminderText()}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          _buildSwitchTile(
            '참여 알림',
            '모임 참여 승인/거절 및 참여자 변동사항을 알림받습니다',
            _participantNotification,
            (value) {
              setState(() => _participantNotification = value);
              _saveSettings();
            },
          ),
          
          _buildSwitchTile(
            '즐겨찾기 식당 알림',
            '즐겨찾기한 식당에 새로운 모임이 생성될 때 알림을 받습니다',
            _favoriteRestaurantNotification,
            (value) {
              setState(() => _favoriteRestaurantNotification = value);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoNotDisturbSection() {
    return CommonCard(
      margin: AppPadding.horizontal16,
      padding: AppPadding.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bedtime,
                color: AppDesignTokens.primary,
                size: 20,
              ),
              const SizedBox(width: AppDesignTokens.spacing2),
              Text(
                '방해금지 모드',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: AppDesignTokens.fontWeightBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing3),
          
          _buildSwitchTile(
            '방해금지 모드',
            '설정한 시간 동안 알림을 받지 않습니다',
            _doNotDisturbEnabled,
            (value) {
              setState(() => _doNotDisturbEnabled = value);
              _saveSettings();
            },
          ),
          
          if (_doNotDisturbEnabled) ...[
            const SizedBox(height: AppDesignTokens.spacing3),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(true),
                    borderRadius: AppBorderRadius.medium,
                    child: Container(
                      padding: AppPadding.all12,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: AppBorderRadius.medium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '시작 시간',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: AppDesignTokens.spacing1),
                          Text(
                            _formatTime(_doNotDisturbStart),
                            style: AppTextStyles.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing2),
                Text(
                  '~',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: AppDesignTokens.spacing2),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(false),
                    borderRadius: AppBorderRadius.medium,
                    child: Container(
                      padding: AppPadding.all12,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: AppBorderRadius.medium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '종료 시간',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: AppDesignTokens.spacing1),
                          Text(
                            _formatTime(_doNotDisturbEnd),
                            style: AppTextStyles.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesignTokens.spacing1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: AppDesignTokens.fontWeightMedium,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing1),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacing2),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppDesignTokens.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}