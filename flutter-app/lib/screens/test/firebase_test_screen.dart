import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/meeting_service.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../models/meeting.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import 'fcm_test_screen.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  bool _isLoading = false;
  String _message = '';
  List<Map<String, dynamic>> _vocMessages = [];

  Future<void> _analyzeVOCMessages() async {
    setState(() {
      _isLoading = true;
      _message = 'VOC 메시지 분석 중...';
      _vocMessages.clear();
    });

    try {
      // VOC 관련 키워드 목록
      final vocKeywords = [
        '버그', '에러', '오류', '문제', '불편', '개선', '요청', '제안',
        '안돼', '안됨', '작동안함', '실행안됨', '느림', '늦음',
        '기능', '추가', '수정', '바꿔', '변경', '업데이트',
        '이상해', '이상함', '웹뷰', '지도', '검색', '로그인',
        '앱', '화면', '버튼', '클릭', '터치', '반응', '응답',
        '빠져나가', '나가짐', '꺼짐', '종료', '멈춤', '중단',
        '로딩', '기다림', '시간', '오래걸림'
      ];

      // 모든 메시지 가져오기
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1000) // 최근 1000개 메시지
          .get();

      List<Map<String, dynamic>> vocCandidates = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final content = (data['content'] as String? ?? '').toLowerCase();
        final messageType = data['type'] as String? ?? 'text';
        
        // 시스템 메시지 제외
        if (messageType == 'system') continue;
        
        // VOC 키워드 검색
        bool hasVOCKeyword = vocKeywords.any((keyword) => 
          content.contains(keyword.toLowerCase()));
        
        // 특정 패턴 검색 (질문, 불만, 제안)
        bool hasQuestionPattern = content.contains('?') || 
                                 content.contains('어떻게') ||
                                 content.contains('왜') ||
                                 content.contains('언제');
        
        bool hasComplaintPattern = content.contains('안') && 
                                  (content.contains('돼') || content.contains('됨'));
        
        // 긴 메시지 (상세한 피드백 가능성)
        bool isLongMessage = content.length > 50;
        
        if (hasVOCKeyword || hasQuestionPattern || hasComplaintPattern || isLongMessage) {
          vocCandidates.add({
            'id': doc.id,
            'meetingId': data['meetingId'] ?? '',
            'senderName': data['senderName'] ?? '',
            'content': data['content'] ?? '',
            'createdAt': data['createdAt'] as Timestamp?,
            'type': messageType,
            'vocScore': _calculateVOCScore(content, vocKeywords),
            'reason': _getVOCReason(content, hasVOCKeyword, hasQuestionPattern, hasComplaintPattern, isLongMessage),
          });
        }
      }

      // VOC 점수 순으로 정렬
      vocCandidates.sort((a, b) => (b['vocScore'] as int).compareTo(a['vocScore'] as int));
      
      setState(() {
        _vocMessages = vocCandidates.take(50).toList(); // 상위 50개만
        _message = '✅ VOC 분석 완료! ${_vocMessages.length}개의 잠재적 VOC 메시지 발견';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = '❌ VOC 분석 실패: $e';
        _isLoading = false;
      });
    }
  }

  int _calculateVOCScore(String content, List<String> vocKeywords) {
    int score = 0;
    final lowerContent = content.toLowerCase();
    
    // 키워드 매칭 점수
    for (final keyword in vocKeywords) {
      if (lowerContent.contains(keyword.toLowerCase())) {
        score += 10;
      }
    }
    
    // 패턴 점수
    if (lowerContent.contains('?')) score += 5;
    if (lowerContent.contains('어떻게')) score += 8;
    if (lowerContent.contains('왜')) score += 8;
    if (lowerContent.contains('안돼') || lowerContent.contains('안됨')) score += 15;
    
    // 길이 점수
    if (content.length > 100) score += 10;
    if (content.length > 200) score += 15;
    
    return score;
  }

  String _getVOCReason(String content, bool hasKeyword, bool hasQuestion, bool hasComplaint, bool isLong) {
    List<String> reasons = [];
    if (hasKeyword) reasons.add('VOC키워드');
    if (hasQuestion) reasons.add('질문패턴');
    if (hasComplaint) reasons.add('불만패턴');
    if (isLong) reasons.add('긴메시지');
    return reasons.join(', ');
  }

  Future<void> _deleteProblematicUser() async {
    setState(() {
      _isLoading = true;
      _message = '문제 사용자 삭제 중...';
    });

    try {
      // 카카오 ID로 사용자 찾기
      final user = await UserService.getUserByKakaoId('4323196821');
      if (user != null) {
        // 사용자 삭제
        await UserService.deleteUser(user.id);
        setState(() {
          _message = '✅ 문제 사용자 삭제 완료! (${user.name})';
          _isLoading = false;
        });
      } else {
        setState(() {
          _message = '❌ 해당 카카오 ID의 사용자를 찾을 수 없음';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = '❌ 사용자 삭제 실패: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addSampleData() async {
    setState(() {
      _isLoading = true;
      _message = '샘플 데이터 추가 중...';
    });

    try {
      // 샘플 사용자 생성
      final sampleUser = User(
        id: 'test_user_${DateTime.now().millisecondsSinceEpoch}',
        name: '테스트 사용자',
        email: 'test@example.com',
        rating: 5.0,
      );
      
      await UserService.createUser(sampleUser);

      // 샘플 모임 생성
      final sampleMeeting = Meeting(
        id: 'test_meeting_${DateTime.now().millisecondsSinceEpoch}',
        description: 'Firebase 테스트용 모임입니다. 같이 맛있는 거 먹어요!',
        location: '서울시 강남구 강남역',
        dateTime: DateTime.now().add(const Duration(hours: 3)),
        maxParticipants: 4,
        currentParticipants: 1,
        hostId: sampleUser.id,
        hostName: sampleUser.name,
        tags: ['테스트', '강남', '맛집'],
        participantIds: [sampleUser.id],
        latitude: 37.4979,
        longitude: 127.0276,
        restaurantName: '테스트 레스토랑',
      );

      await MeetingService.createMeeting(sampleMeeting);

      setState(() {
        _message = '✅ 샘플 데이터 추가 완료!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = '❌ 오류 발생: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase 테스트'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Firebase 연결 테스트',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeVOCMessages,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('VOC 메시지 분석'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _deleteProblematicUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('문제 사용자 삭제'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FCMTestScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2B48C),
                foregroundColor: Colors.white,
              ),
              child: const Text('FCM 알림 테스트'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _addSampleData,
              child: const Text('샘플 데이터 추가'),
            ),
            const SizedBox(height: 20),
            if (_message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: _message.contains('✅') 
                      ? Colors.green.shade100 
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _message.contains('✅') 
                        ? Colors.green.shade800 
                        : Colors.red.shade800,
                  ),
                ),
              ),
            const SizedBox(height: 40),
            StreamBuilder<List<Meeting>>(
              stream: MeetingService.getMeetingsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    '현재 모임 수: ${snapshot.data!.length}개',
                    style: const TextStyle(fontSize: 18),
                  );
                }
                return const CircularProgressIndicator();
              },
            ),
            // VOC 결과 표시
            if (_vocMessages.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'VOC 메시지 분석 결과',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 400,
                child: ListView.builder(
                  itemCount: _vocMessages.length,
                  itemBuilder: (context, index) {
                    final message = _vocMessages[index];
                    final createdAt = message['createdAt'] as Timestamp?;
                    final dateString = createdAt?.toDate().toString().substring(0, 19) ?? '날짜 없음';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      child: ExpansionTile(
                        title: Text(
                          '${message['senderName']} (점수: ${message['vocScore']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('모임: ${message['meetingId']}'),
                            Text('이유: ${message['reason']}'),
                            Text('시간: $dateString'),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '메시지 내용:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    message['content'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      size: 16,
                                      color: _getVOCColor(message['vocScore'] as int),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getVOCLevel(message['vocScore'] as int),
                                      style: TextStyle(
                                        color: _getVOCColor(message['vocScore'] as int),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getVOCColor(int score) {
    if (score >= 50) return Colors.red;
    if (score >= 30) return Colors.orange;
    if (score >= 15) return Colors.yellow.shade700;
    return Colors.blue;
  }

  String _getVOCLevel(int score) {
    if (score >= 50) return '긴급';
    if (score >= 30) return '높음';
    if (score >= 15) return '보통';
    return '낮음';
  }
}