/**
 * 테스트용 평점 데이터를 Firestore에 추가하는 스크립트
 * main.dart에서 임시로 호출하여 사용
 */

import 'package:cloud_firestore/cloud_firestore.dart';

class TestRatingsAdder {
  static Future<void> addTestRatings() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 테스트 평점 데이터
      final testRatings = [
        {
          'name': '제주은희네해장국',
          'address': '서울 강남구 테헤란로 123',
          'latitude': 37.5012743,
          'longitude': 127.0396587,
          'naverRating': {
            'score': 4.2,
            'reviewCount': 847,
            'url': 'https://map.naver.com/v5/entry/place/27184746'
          },
          'kakaoRating': {
            'score': 4.1,
            'reviewCount': 234,
            'url': 'https://place.map.kakao.com/27184746'
          },
          'category': '음식점 > 한식 > 해장국',
          'deepLinks': {
            'naver': 'nmap://place?id=27184746',
            'kakao': 'kakaomap://place?id=27184746'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '맘스터치',
          'address': '서울 강남구 역삼로 456',
          'latitude': 37.5001234,
          'longitude': 127.0385678,
          'naverRating': {
            'score': 4.0,
            'reviewCount': 523,
            'url': 'https://map.naver.com/v5/entry/place/12345678'
          },
          'kakaoRating': {
            'score': 3.9,
            'reviewCount': 198,
            'url': 'https://place.map.kakao.com/12345678'
          },
          'category': '음식점 > 패스트푸드 > 햄버거',
          'deepLinks': {
            'naver': 'nmap://place?id=12345678',
            'kakao': 'kakaomap://place?id=12345678'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '스타벅스',
          'address': '서울 강남구 강남대로 789',
          'latitude': 37.4979876,
          'longitude': 127.0276543,
          'naverRating': {
            'score': 4.3,
            'reviewCount': 1256,
            'url': 'https://map.naver.com/v5/entry/place/87654321'
          },
          'kakaoRating': {
            'score': 4.2,
            'reviewCount': 876,
            'url': 'https://place.map.kakao.com/87654321'
          },
          'category': '음식점 > 카페 > 커피전문점',
          'deepLinks': {
            'naver': 'nmap://place?id=87654321',
            'kakao': 'kakaomap://place?id=87654321'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '김밥천국',
          'address': '서울 강남구 논현로 321',
          'latitude': 37.5089876,
          'longitude': 127.0198765,
          'naverRating': {
            'score': 3.8,
            'reviewCount': 334,
            'url': 'https://map.naver.com/v5/entry/place/11223344'
          },
          'category': '음식점 > 분식 > 김밥',
          'deepLinks': {
            'naver': 'nmap://place?id=11223344'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      // 각 평점 데이터를 Firestore에 저장
      for (int i = 0; i < testRatings.length; i++) {
        final docId = 'test_rating_${i + 1}';
        await firestore
            .collection('restaurant_ratings')
            .doc(docId)
            .set(testRatings[i]);
        
        print('✅ 테스트 평점 데이터 추가: ${testRatings[i]['name']}');
      }

      print('🎉 모든 테스트 평점 데이터 추가 완료! (${testRatings.length}개)');
      
    } catch (e) {
      print('❌ 테스트 평점 데이터 추가 실패: $e');
    }
  }
}