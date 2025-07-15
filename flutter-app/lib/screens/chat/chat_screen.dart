import 'package:flutter/material.dart';
import '../../components/common/common_confirm_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String meetingTitle;
  final String chatRoomId;
  
  const ChatScreen({
    super.key,
    required this.meetingTitle,
    required this.chatRoomId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // 샘플 메시지 데이터
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      senderId: 'host',
      senderName: '김민수',
      message: '안녕하세요! 강남 맛집 탐방 모임을 만든 김민수입니다.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isHost: true,
    ),
    ChatMessage(
      id: '2',
      senderId: 'user1',
      senderName: '박지영',
      message: '안녕하세요~ 참여하게 되어 기뻐요!',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
      isHost: false,
    ),
    ChatMessage(
      id: '3',
      senderId: 'me',
      senderName: '나',
      message: '저도 잘 부탁드립니다!',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      isHost: false,
    ),
    ChatMessage(
      id: '4',
      senderId: 'host',
      senderName: '김민수',
      message: '그럼 내일 6시에 강남역 2번 출구에서 만날까요?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isHost: true,
    ),
    ChatMessage(
      id: '5',
      senderId: 'user1',
      senderName: '박지영',
      message: '좋아요! 혹시 연락처도 공유할까요?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      isHost: false,
    ),
    ChatMessage(
      id: '6',
      senderId: 'me',
      senderName: '나',
      message: '네! 내일 6시에 봬요 😊',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isHost: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.meetingTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '3명 참여 중',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showChatMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 채팅 메시지 영역
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == 'me';
                final showDateSeparator = index == 0 || 
                  !_isSameDay(_messages[index - 1].timestamp, message.timestamp);
                
                return Column(
                  children: [
                    if (showDateSeparator) _buildDateSeparator(message.timestamp),
                    _buildMessageBubble(message, isMe),
                  ],
                );
              },
            ),
          ),
          
          // 메시지 입력 영역
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isHost 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainer,
              child: Text(
                message.senderName[0],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: message.isHost 
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (message.isHost) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '호스트',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMe) ...[
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message.message,
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe 
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    
                    if (!isMe) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                message.senderName[0],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => _showMoreOptions(),
              icon: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(text),
              ),
            ),
            
            const SizedBox(width: 8),
            
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                onPressed: () => _sendMessage(_messageController.text),
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'me',
      senderName: '나',
      message: text.trim(),
      timestamp: DateTime.now(),
      isHost: false,
    );
    
    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });
    
    // 스크롤을 맨 아래로
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionButton(
                  icon: Icons.photo_library,
                  label: '사진',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('사진 선택 기능 준비 중'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
                _buildOptionButton(
                  icon: Icons.location_on,
                  label: '위치',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('위치 공유 기능 준비 중'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
                _buildOptionButton(
                  icon: Icons.calculate,
                  label: '더치페이',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('더치페이 계산기 기능 준비 중'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('모임 정보'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('모임 정보 화면으로 이동'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.notifications_off),
              title: const Text('알림 끄기'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('알림을 껐습니다'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red[400]),
              title: Text('채팅방 나가기', style: TextStyle(color: Colors.red[400])),
              onTap: () {
                Navigator.pop(context);
                _showExitConfirmDialog();
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmDialog() async {
    final confirmed = await CommonConfirmDialog.showWarning(
      context: context,
      title: '채팅방 나가기',
      content: '정말 채팅방을 나가시겠습니까?\n대화 내용이 삭제됩니다.',
      confirmText: '나가기',
      cancelText: '취소',
    );
    
    if (confirmed) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('채팅방을 나갔습니다'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return '오늘';
    } else if (difference == 1) {
      return '어제';
    } else {
      return '${date.month}월 ${date.day}일';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}

// 채팅 메시지 데이터 모델
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isHost;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isHost,
  });
}