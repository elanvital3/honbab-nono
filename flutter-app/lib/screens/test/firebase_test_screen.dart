import 'package:flutter/material.dart';
import '../../services/meeting_service.dart';
import '../../services/user_service.dart';
import '../../models/meeting.dart';
import '../../models/user.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  bool _isLoading = false;
  String _message = '';

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
              onPressed: _isLoading ? null : _deleteProblematicUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('문제 사용자 삭제'),
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
          ],
        ),
      ),
    );
  }
}