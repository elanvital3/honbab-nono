import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/meeting.dart';
import '../../models/message.dart';
import '../../models/user.dart' as app_user;
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/meeting_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final Meeting meeting;

  const ChatRoomScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _currentUserId;
  app_user.User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    try {
      final currentFirebaseUser = AuthService.currentFirebaseUser;
      if (currentFirebaseUser != null) {
        _currentUserId = currentFirebaseUser.uid;
        final user = await UserService.getUser(_currentUserId!);
        if (user != null) {
          _currentUser = user;
          
          // 메시지 읽음 처리
          await ChatService.markMessagesAsRead(widget.meeting.id, _currentUserId!);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 초기화 실패: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUser == null) return;
    
    // 완료된 모임인 경우 메시지 전송 불가
    if (widget.meeting.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('완료된 모임에서는 메시지를 보낼 수 없습니다'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await ChatService.sendMessage(
        meetingId: widget.meeting.id,
        senderId: _currentUser!.id,
        senderName: _currentUser!.name,
        senderProfileImage: _currentUser!.profileImageUrl,
        content: content,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 메시지 전송 실패: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메시지 전송에 실패했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.meeting.restaurantName ?? widget.meeting.location),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<Meeting>>(
      stream: MeetingService.getMeetingsStream(),
      builder: (context, meetingSnapshot) {
        // 현재 모임 정보 실시간 업데이트
        Meeting currentMeeting = widget.meeting;
        if (meetingSnapshot.hasData) {
          try {
            currentMeeting = meetingSnapshot.data!.firstWhere(
              (meeting) => meeting.id == widget.meeting.id,
            );
          } catch (e) {
            // 모임이 삭제된 경우 기본값 사용
            currentMeeting = widget.meeting;
          }
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 1,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentMeeting.restaurantName ?? currentMeeting.location,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${currentMeeting.currentParticipants}명 참여중',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: 모임 정보 보기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('모임 정보 기능 준비 중입니다')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 메시지 리스트
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: ChatService.getMessagesStream(widget.meeting.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('메시지를 불러오는 중 오류가 발생했습니다'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '첫 번째 메시지를 보내보세요!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 메시지가 추가될 때마다 자동 스크롤
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMyMessage = message.senderId == _currentUserId;
                    final isSystemMessage = message.type == MessageType.system;

                    if (isSystemMessage) {
                      return _buildSystemMessage(message);
                    }

                    return _buildMessage(message, isMyMessage);
                  },
                );
              },
            ),
          ),

          // 메시지 입력창
          _buildMessageInput(currentMeeting),
        ],
      ),
        );
      },
    );
  }

  Widget _buildMessage(Message message, bool isMyMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              backgroundImage: message.senderProfileImage != null 
                ? NetworkImage(message.senderProfileImage!)
                : null,
              child: message.senderProfileImage == null
                ? Text(
                    message.senderName[0],
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMyMessage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMyMessage 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomLeft: isMyMessage ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isMyMessage ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isMyMessage 
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            Text(
              message.shortTime,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Message message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput(Meeting meeting) {
    final isCompleted = meeting.status == 'completed';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: isCompleted
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '완료된 모임입니다. 메시지를 보낼 수 없습니다.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}