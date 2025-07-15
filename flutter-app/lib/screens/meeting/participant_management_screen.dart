import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/meeting.dart';
import '../../models/user.dart' as app_user;
import '../../services/user_service.dart';
import '../../services/meeting_service.dart';
import '../../services/chat_service.dart';
import '../../components/common/common_confirm_dialog.dart';

class ParticipantManagementScreen extends StatefulWidget {
  final Meeting meeting;

  const ParticipantManagementScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<ParticipantManagementScreen> createState() => _ParticipantManagementScreenState();
}

class _ParticipantManagementScreenState extends State<ParticipantManagementScreen> {
  List<app_user.User> _participants = [];
  bool _isLoading = true;
  bool _hasChanges = false; // 변경사항 추적

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<app_user.User> participantUsers = [];
      
      for (final participantId in widget.meeting.participantIds) {
        final user = await UserService.getUser(participantId);
        if (user != null) {
          participantUsers.add(user);
        }
      }
      
      // 호스트를 맨 앞으로 정렬
      participantUsers.sort((a, b) {
        if (a.id == widget.meeting.hostId) return -1;
        if (b.id == widget.meeting.hostId) return 1;
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _participants = participantUsers;
      });
      
      if (kDebugMode) {
        print('✅ 참여자 목록 로드 완료: ${_participants.length}명');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 참여자 목록 로드 실패: $e');
      }
      _showErrorMessage('참여자 목록을 불러오는 데 실패했습니다');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeParticipant(app_user.User participant) async {
    final confirmed = await _showConfirmDialog(
      '참여자 강제 퇴장',
      '${participant.name}님을 모임에서 내보내시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
    );

    if (!confirmed) return;

    try {
      await MeetingService.leaveMeeting(widget.meeting.id, participant.id);
      
      // 퇴장 시스템 메시지 전송
      await ChatService.sendSystemMessage(
        meetingId: widget.meeting.id,
        content: '${participant.name}님이 호스트에 의해 모임에서 나갔습니다.',
      );

      // 참여자 목록 새로고침
      await _loadParticipants();
      
      // 변경사항 표시
      setState(() {
        _hasChanges = true;
      });

      _showSuccessMessage('${participant.name}님이 모임에서 제외되었습니다');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 참여자 제거 실패: $e');
      }
      _showErrorMessage('참여자 제거에 실패했습니다: $e');
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await CommonConfirmDialog.showDelete(
      context: context,
      title: title,
      content: content,
      confirmText: '제거',
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        title: Text('참여자 관리 (${_participants.length}명)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _participants.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('참여자가 없습니다'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _participants.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final participant = _participants[index];
                    final isHost = participant.id == widget.meeting.hostId;
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 프로필 이미지
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isHost 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainer,
                              backgroundImage: participant.profileImageUrl != null
                                  ? NetworkImage(participant.profileImageUrl!)
                                  : null,
                              child: participant.profileImageUrl == null
                                  ? Text(
                                      participant.name[0],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isHost 
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : null,
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // 사용자 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        participant.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            '호스트',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (participant.bio != null && participant.bio!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      participant.bio!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        participant.rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.group,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '참여 ${participant.meetingsJoined}회',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // 강제 퇴장 버튼 (호스트가 아닌 경우만)
                            if (!isHost)
                              IconButton(
                                onPressed: () => _removeParticipant(participant),
                                icon: const Icon(Icons.person_remove),
                                color: Colors.red,
                                tooltip: '강제 퇴장',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}