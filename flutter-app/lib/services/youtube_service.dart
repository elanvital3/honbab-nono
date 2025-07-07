import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/restaurant.dart';

class YoutubeService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3/search';
  
  static String get _apiKey {
    final key = dotenv.env['YOUTUBE_API_KEY'] ?? '';
    if (key.isEmpty) {
      print('⚠️ YOUTUBE_API_KEY 환경변수가 비어있음');
    }
    return key;
  }

  /// 식당 이름으로 유튜브 검색
  static Future<YoutubeStats?> searchRestaurantVideos(
    String restaurantName,
    String address
  ) async {
    try {
      print('🎥 유튜브 검색: $restaurantName (주소: $address)');
      
      // 검색어 생성 (식당명 + 맛집 키워드)
      final searchQuery = '$restaurantName 맛집';
      
      final encodedQuery = Uri.encodeQueryComponent(searchQuery);
      final url = '$_baseUrl?part=snippet&type=video&q=$encodedQuery&maxResults=10&key=$_apiKey';
      
      print('📡 유튜브 API 요청: $searchQuery');
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        
        if (items.isEmpty) {
          print('📭 유튜브 검색 결과 없음');
          return null;
        }
        
        // 채널 정보 수집
        final channels = <String>{};
        RepresentativeVideo? representativeVideo;
        String? firstMentionDate;
        String? lastMentionDate;
        
        for (final item in items) {
          final snippet = item['snippet'] as Map<String, dynamic>;
          final channelTitle = snippet['channelTitle'] as String? ?? '';
          final publishedAt = snippet['publishedAt'] as String? ?? '';
          
          channels.add(channelTitle);
          
          // 첫 번째 비디오를 대표 비디오로 설정
          if (representativeVideo == null) {
            representativeVideo = RepresentativeVideo(
              title: snippet['title'] as String? ?? '',
              channelName: channelTitle,
              videoId: (item['id'] as Map<String, dynamic>)['videoId'] as String? ?? '',
              viewCount: 0, // YouTube Search API는 조회수 제공 안함
              publishedAt: publishedAt,
              thumbnailUrl: (snippet['thumbnails'] as Map<String, dynamic>?)?['default']?['url'] as String?,
            );
          }
          
          // 첫 번째와 마지막 언급 날짜 업데이트
          if (firstMentionDate == null || publishedAt.compareTo(firstMentionDate) < 0) {
            firstMentionDate = publishedAt;
          }
          if (lastMentionDate == null || publishedAt.compareTo(lastMentionDate) > 0) {
            lastMentionDate = publishedAt;
          }
        }
        
        // 최근 30일 내 영상 수 계산 (실제로는 모든 검색 결과를 최근 것으로 간주)
        final recentMentions = items.length;
        
        final youtubeStats = YoutubeStats(
          mentionCount: items.length,
          channels: channels.toList(),
          firstMentionDate: firstMentionDate,
          lastMentionDate: lastMentionDate,
          recentMentions: recentMentions,
          representativeVideo: representativeVideo,
        );
        
        print('✅ 유튜브 검색 완료: ${items.length}개 영상, ${channels.length}개 채널');
        
        return youtubeStats;
        
      } else {
        print('❌ 유튜브 API 에러: ${response.statusCode}');
        print('❌ 응답: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 유튜브 검색 중 오류: $e');
      return null;
    }
  }

  /// API 키 테스트
  static Future<bool> testApiKey() async {
    try {
      print('🧪 유튜브 API 키 테스트 시작');
      
      final encodedQuery = Uri.encodeQueryComponent('맛집');
      final url = '$_baseUrl?part=snippet&type=video&q=$encodedQuery&maxResults=1&key=$_apiKey';
      
      final response = await http.get(Uri.parse(url));

      final isValid = response.statusCode == 200;
      print('🧪 유튜브 API 키 테스트 결과: ${isValid ? "성공" : "실패"} (${response.statusCode})');
      
      if (!isValid) {
        print('❌ 응답: ${response.body}');
      }
      
      return isValid;
    } catch (e) {
      print('❌ 유튜브 API 키 테스트 오류: $e');
      return false;
    }
  }
}