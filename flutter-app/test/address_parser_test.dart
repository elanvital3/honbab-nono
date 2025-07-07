import 'package:flutter_test/flutter_test.dart';
import 'package:honbab_nono/utils/address_parser.dart';

void main() {
  group('AddressParser 테스트', () {
    test('주소에서 지역 키워드 추출', () {
      final address = '서울특별시 강남구 역삼동 123-45';
      final keywords = AddressParser.extractLocationKeywords(address);
      
      expect(keywords, contains('서울'));
      expect(keywords, contains('강남구'));
      expect(keywords, contains('역삼동'));
    });

    test('검색어 조합 생성', () {
      final restaurantName = '대춘해장국';
      final address = '서울특별시 강남구 역삼동';
      final queries = AddressParser.generateSearchQueries(restaurantName, address);
      
      expect(queries, contains('대춘해장국 맛집'));
      expect(queries, contains('대춘해장국 서울 맛집'));
      expect(queries, contains('대춘해장국 강남구 맛집'));
      expect(queries, contains('대춘해장국 역삼동 맛집'));
    });

    test('관련성 점수 계산', () {
      final restaurantName = '대춘해장국';
      final address = '서울특별시 강남구 역삼동';
      final blogTitle = '강남 대춘해장국 후기';
      final blogDescription = '역삼동에 있는 대춘해장국 다녀왔어요';
      
      final score = AddressParser.calculateRelevanceScore(
        restaurantName, 
        address, 
        blogTitle, 
        blogDescription
      );
      
      expect(score, greaterThan(50)); // 식당명 + 지역명 포함으로 높은 점수
    });

    test('관련 없는 블로그 낮은 점수', () {
      final restaurantName = '대춘해장국';
      final address = '서울특별시 강남구 역삼동';
      final blogTitle = '부산 여행 후기';
      final blogDescription = '부산에서 먹은 음식들';
      
      final score = AddressParser.calculateRelevanceScore(
        restaurantName, 
        address, 
        blogTitle, 
        blogDescription
      );
      
      expect(score, lessThan(30)); // 관련성 낮음
    });

    test('광고성 포스트 감점', () {
      final restaurantName = '대춘해장국';
      final address = '서울특별시 강남구 역삼동';
      final blogTitle = '대춘해장국 광고 협찬 포스팅';
      final blogDescription = '제공받아서 다녀온 대춘해장국 후기';
      
      final score = AddressParser.calculateRelevanceScore(
        restaurantName, 
        address, 
        blogTitle, 
        blogDescription
      );
      
      expect(score, lessThan(50)); // 광고성 키워드로 감점
    });
  });
}