import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../services/meeting_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../styles/text_styles.dart';
import '../screens/chat/chat_room_screen.dart';
import '../components/participant_profile_widget.dart';

class ChatListTab extends StatefulWidget {
  final void Function(int count)? onUnreadCountChanged;
  
  const ChatListTab({
    super.key, 
    this.onUnreadCountChanged,
  });

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab>
    with AutomaticKeepAliveClientMixin {
  // FirebaseFirestore 인스턴스 (현재 미사용이지만 향후 확장 가능성을 위해 유지)
  // static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;
  List<Meeting> _participatingMeetings = [];
  final Map<String, Message?> _lastMessages = {};
  // ValueNotifier로 변경 - setState 없이 UI 업데이트
  final Map<String, ValueNotifier<int>> _unreadCountNotifiers = {};
  final ValueNotifier<int> _totalUnreadCountNotifier = ValueNotifier<int>(0);
  bool _isLoading = true;
  StreamSubscription<List<Meeting>>? _meetingsSubscription;
  final Map<String, StreamSubscription<Message?>> _messageStreamSubscriptions = {};
  final Map<String, StreamSubscription<int>> _unreadCountStreamSubscriptions = {};
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
      (total, notifier) => total + notifier.value,
    );
    if (_totalUnreadCountNotifier.value != newTotal) {
      _totalUnreadCountNotifier.value = newTotal; // ValueNotifier 업데이트만!

      // 전역 notifier도 업데이트 (HomeScreen 배지용)
      widget.onUnreadCountChanged?.call(newTotal);

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
          (unreadCount) {
            if (!mounted) return;

            try {
              final currentNotifier = _unreadCountNotifiers[meetingId]!;
              final previousCount = currentNotifier.value;

              // 카운트가 실제로 변경된 경우에만 업데이트 (setState 없음!)
              if (previousCount != unreadCount) {
                currentNotifier.value = unreadCount; // 이 부분만 리빌드됨!
                _updateTotalUnreadCount(); // 총 개수 업데이트

                // 디바운스된 방식으로 부모에게 알림
                _notifyParentWithDebounce();
                if (kDebugMode) {
                  print('🔢 안읽은 메시지 수 변경: $meetingId -> $unreadCount (전체 리빌드 없음!)');
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
                              if (unreadCount <= 0) {
                                return const SizedBox.shrink();
                              }

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

    if (!mounted) return;
    
    await Navigator.push(
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