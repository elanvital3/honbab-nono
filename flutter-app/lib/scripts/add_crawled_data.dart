/**
 * 크롤링으로 수집한 실제 데이터를 Firestore에 추가하는 스크립트
 * Flutter 앱 내에서 실행 (Firebase 인증 문제 해결)
 */

import 'package:cloud_firestore/cloud_firestore.dart';

class CrawledDataAdder {
  static Future<void> addCrawledData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 실제 크롤링으로 수집한 데이터들
      final crawledData = [
        {
          'name': '제주은희네해장국 증산점',
          'address': '서울특별시 은평구 증산로 335 1층',
          'latitude': 37.5864244,
          'longitude': 126.9119519,
          'naverRating': null, // 평점 스크래핑 추가 필요
          'category': '음식점 > 한식 > 해장국',
          'source': 'naver_crawler',
          'deepLinks': {
            'naver': 'https://map.naver.com/search/제주은희네해장국 증산점'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '제주은희네해장국 잠실직영점',
          'address': '서울 송파구 송파대로49길 10',
          'latitude': 37.507835571037,
          'longitude': 127.103465183397,
          'kakaoRating': {
            'score': 0.0, // 실제 평점 스크래핑 필요
            'reviewCount': 0,
            'url': 'http://place.map.kakao.com/130546853'
          },
          'category': '음식점 > 한식 > 해장국 > 제주은희네해장국',
          'source': 'kakao_crawler',
          'deepLinks': {
            'kakao': 'kakaomap://place?id=130546853'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '맘스터치 강남역점',
          'address': '서울 강남구 강남대로100길 10',
          'latitude': 37.50163205822193,
          'longitude': 127.02687067863272,
          'kakaoRating': {
            'score': 0.0,
            'reviewCount': 0,
            'url': 'http://place.map.kakao.com/794775769'
          },
          'category': '음식점 > 패스트푸드 > 맘스터치',
          'source': 'kakao_crawler',
          'deepLinks': {
            'kakao': 'kakaomap://place?id=794775769'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '맘스터치 서울시청점',
          'address': '서울특별시 중구 무교로 12 2층',
          'latitude': 37.5670285,
          'longitude': 126.979375,
          'naverRating': null,
          'category': '음식점 > 패스트푸드',
          'source': 'naver_crawler',
          'deepLinks': {
            'naver': 'https://map.naver.com/search/맘스터치 서울시청점'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': '김밥천국',
          'address': '서울 강남구 학동로4길 20',
          'latitude': 37.51007884829808,
          'longitude': 127.02325435196214,
          'kakaoRating': {
            'score': 0.0,
            'reviewCount': 0,
            'url': 'http://place.map.kakao.com/8802110'
          },
          'category': '음식점 > 분식',
          'source': 'kakao_crawler',
          'deepLinks': {
            'kakao': 'kakaomap://place?id=8802110'
          },
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      // 각 크롤링 데이터를 Firestore에 저장
      for (int i = 0; i < crawledData.length; i++) {
        final docId = 'crawled_data_${i + 1}';
        await firestore
            .collection('restaurant_ratings')
            .doc(docId)
            .set(crawledData[i]);
        
        print('✅ 크롤링 데이터 추가: ${crawledData[i]['name']}');
      }

      print('🎉 모든 크롤링 데이터 추가 완료! (${crawledData.length}개)');
      print('');
      print('📍 추가된 실제 위치들:');
      print('   1. 제주은희네해장국 증산점 (은평구)');
      print('   2. 제주은희네해장국 잠실직영점 (송파구)');
      print('   3. 맘스터치 강남역점 (강남구)');
      print('   4. 맘스터치 서울시청점 (중구)');
      print('   5. 김밥천국 (강남구)');
      print('');
      print('🔗 딥링크 테스트 가능');
      print('🗺️ 지도에서 실제 위치 표시됨');
      
    } catch (e) {
      print('❌ 크롤링 데이터 추가 실패: $e');
    }
  }
}