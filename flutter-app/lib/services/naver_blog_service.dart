import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/restaurant.dart';
import '../utils/address_parser.dart';

class NaverBlogService {
  static const String _baseUrl = 'https://openapi.naver.com/v1/search/blog.json';
  
  static String get _clientId {
    final key = dotenv.env['NAVER_CLIENT_ID'] ?? '';
    if (key.isEmpty) {
      print('⚠️ NAVER_CLIENT_ID 환경변수가 비어있음');
    }
    return key;
  }
  
  static String get _clientSecret {
    final key = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
    if (key.isEmpty) {
      print('⚠️ NAVER_CLIENT_SECRET 환경변수가 비어있음');
    }
    return key;
  }

  /// 식당 이름으로 네이버 블로그 검색 (기존 호환성 유지)
  static Future<NaverBlogData?> searchRestaurantBlogs(String restaurantName) async {
    return searchRestaurantBlogsWithAddress(restaurantName, '');
  }

  /// 식당 이름과 주소로 네이버 블로그 검색 (개선된 버전)
  static Future<NaverBlogData?> searchRestaurantBlogsWithAddress(
    String restaurantName, 
    String address
  ) async {
    try {
      print('🔍 네이버 블로그 검색: $restaurantName (주소: $address)');
      
      // 다양한 검색어 조합 생성
      final searchQueries = AddressParser.generateSearchQueries(restaurantName, address);
      print('📝 생성된 검색어들: $searchQueries');
      
      List<NaverBlogPost> allPosts = [];
      int totalCountSum = 0;
      
      // 각 검색어로 검색 수행 (최대 2개)
      for (int i = 0; i < searchQueries.length && i < 2; i++) {
        final query = searchQueries[i];
        final result = await _performSingleSearch(query);
        
        if (result != null) {
          // 관련성 점수 계산하여 필터링
          final relevantPosts = result.posts.where((post) {
            final score = AddressParser.calculateRelevanceScore(
              restaurantName, 
              address, 
              post.title, 
              post.description
            );
            return score >= 30.0; // 30점 이상만 유효한 포스트로 판단
          }).toList();
          
          allPosts.addAll(relevantPosts);
          totalCountSum += result.totalCount;
        }
        
        // API 호출 간격
        if (i < searchQueries.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      
      // 중복 제거 (링크 기준)
      final uniquePosts = <String, NaverBlogPost>{};
      for (final post in allPosts) {
        if (!uniquePosts.containsKey(post.link)) {
          uniquePosts[post.link] = post;
        }
      }
      
      // 관련성 점수순으로 정렬하여 상위 3개만 선택
      final sortedPosts = uniquePosts.values.toList()
        ..sort((a, b) {
          final scoreA = AddressParser.calculateRelevanceScore(
            restaurantName, address, a.title, a.description
          );
          final scoreB = AddressParser.calculateRelevanceScore(
            restaurantName, address, b.title, b.description
          );
          return scoreB.compareTo(scoreA);
        });
      
      final finalPosts = sortedPosts.take(3).toList();
      
      print('✅ 최종 블로그 검색 결과: ${finalPosts.length}개 (필터링됨)');
      for (final post in finalPosts) {
        final score = AddressParser.calculateRelevanceScore(
          restaurantName, address, post.title, post.description
        );
        print('   - ${post.title} (관련성: ${score.toStringAsFixed(1)}점)');
      }
      
      return NaverBlogData(
        totalCount: finalPosts.length, // 🔥 실제 필터링된 블로그 수 사용!
        posts: finalPosts,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('❌ 네이버 블로그 검색 중 오류: $e');
      return null;
    }
  }

  /// 단일 검색어로 블로그 검색 수행
  static Future<NaverBlogData?> _performSingleSearch(String searchQuery) async {
    try {
      final query = Uri.encodeQueryComponent(searchQuery);
      final url = '$_baseUrl?query=$query&display=5&start=1&sort=date';
      
      print('📡 요청: $searchQuery');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final total = data['total'] as int? ?? 0;
        final items = data['items'] as List? ?? [];
        
        final posts = items.map((item) => NaverBlogPost.fromMap(item as Map<String, dynamic>)).toList();
        
        return NaverBlogData(
          totalCount: total,
          posts: posts,
          updatedAt: DateTime.now(),
        );
      } else {
        print('❌ 블로그 API 에러: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 단일 검색 오류: $e');
      return null;
    }
  }

  /// API 키 테스트
  static Future<bool> testApiKey() async {
    try {
      print('🧪 네이버 블로그 API 키 테스트 시작');
      
      final query = Uri.encodeQueryComponent('맛집');
      final url = '$_baseUrl?query=$query&display=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );

      final isValid = response.statusCode == 200;
      print('🧪 API 키 테스트 결과: ${isValid ? "성공" : "실패"} (${response.statusCode})');
      
      if (!isValid) {
        print('❌ 응답: ${response.body}');
      }
      
      return isValid;
    } catch (e) {
      print('❌ API 키 테스트 오류: $e');
      return false;
    }
  }
}