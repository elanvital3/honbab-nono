import 'package:flutter/foundation.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../services/meeting_service.dart';
import '../services/user_service.dart';

class SampleDataSeeder {
  // 개발용 샘플 데이터 추가
  static Future<void> seedSampleData() async {
    if (!kDebugMode) return; // 디버그 모드에서만 실행

    try {
      // 샘플 사용자들 생성
      final sampleUsers = [
        User(
          id: 'sample_user_1',
          name: '김민수',
          email: 'minsu@example.com',
          rating: 4.8,
          meetingsHosted: 5,
          meetingsJoined: 12,
        ),
        User(
          id: 'sample_user_2',
          name: '박지영',
          email: 'jiyoung@example.com',
          rating: 4.6,
          meetingsHosted: 3,
          meetingsJoined: 8,
        ),
        User(
          id: 'sample_user_3',
          name: '이준호',
          email: 'junho@example.com',
          rating: 4.9,
          meetingsHosted: 7,
          meetingsJoined: 15,
        ),
      ];

      for (final user in sampleUsers) {
        await UserService.createUser(user);
      }

      // 샘플 모임들 생성
      final sampleMeetings = [
        Meeting(
          id: 'sample_meeting_1',
          description: '강남역 근처 유명한 일식집에서 같이 저녁 드실 분 모집합니다. 혼자 가기엔 양이 많아서요 ㅠㅠ',
          location: '서울시 강남구 강남역 스시로',
          dateTime: DateTime.now().add(const Duration(hours: 3)),
          maxParticipants: 4,
          currentParticipants: 2,
          hostId: 'sample_user_1',
          hostName: '김민수',
          tags: ['일식', '강남', '저녁'],
          participantIds: ['sample_user_1', 'sample_user_2'],
          latitude: 37.4979,
          longitude: 127.0276,
          restaurantName: '스시로',
        ),
        Meeting(
          id: 'sample_meeting_2',
          description: '인스타에서 본 홍대 카페들 돌아다니며 디저트 먹방! 사진도 서로 찍어줘요~',
          location: '서울시 마포구 홍대입구역 일대',
          dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
          maxParticipants: 3,
          currentParticipants: 1,
          hostId: 'sample_user_2',
          hostName: '박지영',
          tags: ['카페', '디저트', '홍대', '사진'],
          participantIds: ['sample_user_2'],
          latitude: 37.5563,
          longitude: 126.9238,
          restaurantName: '홍대 카페거리',
        ),
        Meeting(
          id: 'sample_meeting_3',
          description: '이태원 멕시칸 음식 맛집에서 타코와 부리토 먹어요! 양이 많아서 나눠먹으면 좋을 것 같아요.',
          location: '서울시 용산구 이태원 엘 또 타코',
          dateTime: DateTime.now().add(const Duration(days: 2)),
          maxParticipants: 4,
          currentParticipants: 4,
          hostId: 'sample_user_3',
          hostName: '이준호',
          tags: ['멕시칸', '이태원', '점심'],
          participantIds: ['sample_user_1', 'sample_user_2', 'sample_user_3', 'sample_user_1'],
          latitude: 37.5347,
          longitude: 126.9947,
          restaurantName: '엘 또 타코',
        ),
        Meeting(
          id: 'sample_meeting_4',
          description: '성수동 감성 카페에서 브런치 먹고 산책해요~ 20대 여성분들 환영!',
          location: '서울시 성동구 성수역 어니언',
          dateTime: DateTime.now().add(const Duration(days: 3, hours: -2)),
          maxParticipants: 3,
          currentParticipants: 2,
          hostId: 'sample_user_2',
          hostName: '박지영',
          tags: ['브런치', '성수동', '카페', '산책'],
          participantIds: ['sample_user_2', 'sample_user_1'],
          latitude: 37.5445,
          longitude: 127.0557,
          restaurantName: '어니언',
        ),
        Meeting(
          id: 'sample_meeting_5',
          description: '어제 용산 아이파크몰에서 맛있게 먹었던 곳이에요! 후기 공유합니다.',
          location: '서울시 용산구 아이파크몰 푸드코트',
          dateTime: DateTime.now().subtract(const Duration(days: 1)),
          maxParticipants: 4,
          currentParticipants: 4,
          hostId: 'sample_user_1',
          hostName: '김민수',
          tags: ['한식', '용산', '후기'],
          participantIds: ['sample_user_1', 'sample_user_2', 'sample_user_3', 'sample_user_2'],
          latitude: 37.5260,
          longitude: 126.9650,
          restaurantName: '아이파크몰 푸드코트',
        ),
      ];

      for (final meeting in sampleMeetings) {
        await MeetingService.createMeeting(meeting);
      }

      if (kDebugMode) {
        print('✅ 샘플 데이터 추가 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 샘플 데이터 추가 실패: $e');
      }
    }
  }

  // Firebase 컬렉션 초기화 (개발용)
  static Future<void> clearAllData() async {
    if (!kDebugMode) return; // 디버그 모드에서만 실행
    
    // TODO: Firestore 컬렉션 삭제 로직 구현
    // 주의: 실제 운영에서는 절대 사용하지 말 것
  }
}