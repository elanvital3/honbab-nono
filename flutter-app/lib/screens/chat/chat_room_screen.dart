import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/meeting.dart';
import '../../models/message.dart';
import '../../models/user.dart' as app_user;
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/meeting_service.dart';
import '../../styles/text_styles.dart';
import '../profile/user_profile_screen.dart';

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
  List<app_user.User> _participants = [];
  bool _isLoadingParticipants = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    
    // 채팅방 나갈 때 추가 읽음 처리 (안전장치)
    if (_currentUserId != null) {
      ChatService.markMessagesAsRead(widget.meeting.id, _currentUserId!).then((_) {
        if (kDebugMode) {
          print('✅ 채팅방 종료 시 읽음 처리 완료');
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('❌ 채팅방 종료 시 읽음 처리 실패: $error');
        }
      });
    }
    
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
                  style: AppTextStyles.headlineMedium,
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
            onPressed: () => _showMeetingInfoModal(),
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

  Future<void> _loadParticipants() async {
    if (kDebugMode) {
      print('🔍 참여자 로딩 시작');
      print('  - 참여자 ID 목록: ${widget.meeting.participantIds}');
      print('  - 참여자 수: ${widget.meeting.participantIds.length}');
    }
    
    if (widget.meeting.participantIds.isEmpty) {
      if (mounted) {
        setState(() {
          _participants = [];
          _isLoadingParticipants = false;
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _isLoadingParticipants = true;
      });
    }
    
    try {
      final List<app_user.User> participantUsers = [];
      
      for (final participantId in widget.meeting.participantIds) {
        if (kDebugMode) {
          print('🔍 사용자 정보 요청: $participantId');
        }
        
        try {
          final user = await UserService.getUser(participantId);
          if (user != null) {
            participantUsers.add(user);
            if (kDebugMode) {
              print('✅ 사용자 정보 로드 성공: ${user.name}');
            }
          } else {
            if (kDebugMode) {
              print('⚠️ 사용자 정보 없음: $participantId');
            }
          }
        } catch (userError) {
          if (kDebugMode) {
            print('❌ 개별 사용자 로드 실패: $participantId, 에러: $userError');
          }
          // 개별 사용자 로드 실패해도 계속 진행
        }
      }
      
      if (kDebugMode) {
        print('📊 최종 로드된 참여자 수: ${participantUsers.length}');
      }
      
      // 호스트를 맨 앞으로 정렬
      participantUsers.sort((a, b) {
        if (a.id == widget.meeting.hostId) return -1;
        if (b.id == widget.meeting.hostId) return 1;
        return 0;
      });
      
      if (mounted) {
        setState(() {
          _participants = participantUsers;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 참여자 목록 로드 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingParticipants = false;
        });
      }
    }
  }

  Future<void> _loadParticipantsForModal(StateSetter setModalState) async {
    if (kDebugMode) {
      print('🔍 모달용 참여자 로딩 시작');
      print('  - 참여자 ID 목록: ${widget.meeting.participantIds}');
      print('  - 참여자 수: ${widget.meeting.participantIds.length}');
    }
    
    if (widget.meeting.participantIds.isEmpty) {
      setModalState(() {
        _participants = [];
        _isLoadingParticipants = false;
      });
      return;
    }
    
    setModalState(() {
      _isLoadingParticipants = true;
    });
    
    try {
      final List<app_user.User> participantUsers = [];
      
      for (final participantId in widget.meeting.participantIds) {
        if (kDebugMode) {
          print('🔍 사용자 정보 요청: $participantId');
        }
        
        try {
          final user = await UserService.getUser(participantId);
          if (user != null) {
            participantUsers.add(user);
            if (kDebugMode) {
              print('✅ 사용자 정보 로드 성공: ${user.name}');
            }
          } else {
            if (kDebugMode) {
              print('⚠️ 사용자 정보 없음: $participantId');
            }
          }
        } catch (userError) {
          if (kDebugMode) {
            print('❌ 개별 사용자 로드 실패: $participantId, 에러: $userError');
          }
        }
      }
      
      if (kDebugMode) {
        print('📊 최종 로드된 참여자 수: ${participantUsers.length}');
      }
      
      // 호스트를 맨 앞으로 정렬
      participantUsers.sort((a, b) {
        if (a.id == widget.meeting.hostId) return -1;
        if (b.id == widget.meeting.hostId) return 1;
        return 0;
      });
      
      setModalState(() {
        _participants = participantUsers;
        _isLoadingParticipants = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 참여자 목록 로드 실패: $e');
      }
      setModalState(() {
        _isLoadingParticipants = false;
      });
    }
  }

  void _showMeetingInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          // 모달 내부에서 한번만 로딩
          if (_participants.isEmpty && !_isLoadingParticipants) {
            _loadParticipantsForModal(setModalState);
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
            // 핸들바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 헤더
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '모임 정보',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // 모임 정보 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMeetingInfoCard(),
                    const SizedBox(height: 16),
                    _buildParticipantsCard(),
                    
                    // 모임 관리 버튼들 (호스트/참여자별로 다름)
                    if (widget.meeting.status != 'completed' && _currentUserId != null) ...[
                      const SizedBox(height: 20),
                      _buildMeetingActionsCard(),
                    ],
                    
                    const SizedBox(height: 20),
                  ],
                ),
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _buildMeetingInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 식당 이름
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.meeting.restaurantName ?? widget.meeting.location,
                  style: AppTextStyles.headlineMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.meeting.status == 'completed'
                      ? Colors.grey
                      : widget.meeting.isAvailable
                          ? Theme.of(context).colorScheme.primary
                          : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.meeting.status == 'completed'
                      ? '완료'
                      : widget.meeting.isAvailable
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
          
          if (widget.meeting.fullAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.meeting.fullAddress!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          
          // 날짜 시간
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                widget.meeting.formattedDateTime,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 인원
          Row(
            children: [
              Icon(Icons.group, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${widget.meeting.participantIds.length}/${widget.meeting.maxParticipants}명',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          if (widget.meeting.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '모임 설명',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.meeting.description,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참여자 (${widget.meeting.participantIds.length}명)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingParticipants)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_participants.isEmpty)
            Text(
              '참여자 정보를 불러올 수 없습니다.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            )
          else
            Column(
              children: _participants.map((participant) {
                final isHost = participant.id == widget.meeting.hostId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            user: participant,
                            isCurrentUser: participant.id == _currentUserId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isHost 
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                : Colors.grey[200],
                            backgroundImage: participant.profileImageUrl != null && 
                                            participant.profileImageUrl!.isNotEmpty
                                ? NetworkImage(participant.profileImageUrl!)
                                : null,
                            child: participant.profileImageUrl == null || 
                                   participant.profileImageUrl!.isEmpty
                                ? Text(
                                    participant.name[0],
                                    style: TextStyle(
                                      color: isHost 
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      participant.name,
                                      style: TextStyle(
                                        fontWeight: isHost ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (isHost) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '호스트',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (participant.bio != null && participant.bio!.isNotEmpty)
                                  Text(
                                    participant.bio!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
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

  Widget _buildMeetingActionsCard() {
    final isHost = _currentUserId == widget.meeting.hostId;
    final isParticipant = widget.meeting.participantIds.contains(_currentUserId);
    
    // 디버깅 정보 출력
    if (kDebugMode) {
      print('🔍 모임 관리 버튼 디버깅:');
      print('  - 현재 사용자 ID: $_currentUserId');
      print('  - 모임 호스트 ID: ${widget.meeting.hostId}');
      print('  - 참여자 ID 목록: ${widget.meeting.participantIds}');
      print('  - 호스트 여부: $isHost');
      print('  - 참여자 여부: $isParticipant');
      if (_currentUser != null) {
        print('  - 현재 사용자 카카오 ID: ${_currentUser!.kakaoId}');
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '모임 관리',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          
          if (isHost)
            // 호스트: 모임 취소 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCancelMeetingDialog(),
                icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                label: const Text(
                  '모임 취소하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else if (isParticipant)
            // 일반 참여자: 모임 나가기 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLeaveMeetingDialog(),
                icon: Icon(Icons.exit_to_app, color: Colors.orange[700]),
                label: Text(
                  '모임 나가기',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            // 호스트도 참여자도 아닌 경우: 소유권 복구 버튼
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '계정 복구로 인해 모임 연결이 끊어진 것 같습니다.',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showOwnershipRecoveryDialog(),
                    icon: const Icon(Icons.restore, color: Colors.white),
                    label: const Text(
                      '모임 소유권 복구',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showCancelMeetingDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 취소'),
        content: const Text(
          '정말로 이 모임을 취소하시겠습니까?\n\n'
          '모임이 취소되면 모든 참여자에게 알림이 전송되고, '
          '채팅방도 함께 삭제됩니다.\n\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              '모임 취소',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelMeeting();
    }
  }

  Future<void> _showLeaveMeetingDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 나가기'),
        content: const Text(
          '정말로 이 모임에서 나가시겠습니까?\n\n'
          '나가신 후에는 다시 참여하려면 새로 신청해야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text(
              '나가기',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _leaveMeeting();
    }
  }

  Future<void> _cancelMeeting() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 모임 삭제
      await MeetingService.deleteMeeting(widget.meeting.id);
      
      // 로딩 닫기
      Navigator.pop(context);
      
      // 모달 닫기
      Navigator.pop(context);
      
      // 채팅방 나가기
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모임이 취소되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // 로딩 닫기
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모임 취소 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveMeeting() async {
    if (_currentUserId == null) return;
    
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 모임 나가기
      await MeetingService.leaveMeeting(widget.meeting.id, _currentUserId!);
      
      // 로딩 닫기
      Navigator.pop(context);
      
      // 모달 닫기
      Navigator.pop(context);
      
      // 채팅방 나가기
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모임에서 나갔습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // 로딩 닫기
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모임 나가기 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showOwnershipRecoveryDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 소유권 복구'),
        content: const Text(
          '계정 복구로 인해 모임 연결이 끊어진 것 같습니다.\n\n'
          '카카오 ID를 기반으로 이 모임의 소유권을 복구하시겠습니까?\n\n'
          '⚠️ 실제 모임 생성자가 아닌 경우 복구하지 마세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              '소유권 복구',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _recoverOwnership();
    }
  }

  Future<void> _recoverOwnership() async {
    if (_currentUserId == null || _currentUser?.kakaoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자 정보를 불러올 수 없습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 기존 호스트의 카카오 ID 확인을 위해 호스트 사용자 정보 조회
      final originalHost = await UserService.getUser(widget.meeting.hostId);
      
      if (originalHost?.kakaoId != _currentUser!.kakaoId) {
        // 로딩 닫기
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카카오 ID가 일치하지 않습니다. 실제 모임 생성자만 복구할 수 있습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 모임의 hostId와 participantIds 업데이트
      final updatedParticipantIds = widget.meeting.participantIds
          .where((id) => id != widget.meeting.hostId) // 기존 호스트 ID 제거
          .toList();
      
      if (!updatedParticipantIds.contains(_currentUserId!)) {
        updatedParticipantIds.add(_currentUserId!); // 새 호스트 ID 추가
      }

      await MeetingService.updateMeeting(widget.meeting.id, {
        'hostId': _currentUserId!,
        'participantIds': updatedParticipantIds,
      });
      
      // 로딩 닫기
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모임 소유권이 복구되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 화면 새로고침을 위해 setState 호출
      setState(() {});
      
    } catch (e) {
      // 로딩 닫기
      Navigator.pop(context);
      
      if (kDebugMode) {
        print('❌ 소유권 복구 실패: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('소유권 복구 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}