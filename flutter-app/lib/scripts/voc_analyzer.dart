import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// VOC 분석을 위한 독립 실행 스크립트
/// 
/// 사용법:
/// 1. Flutter 프로젝트 루트에서 실행
/// 2. dart run lib/scripts/voc_analyzer.dart
/// 
/// 이 스크립트는 Firestore의 messages 컬렉션을 분석하여
/// VOC(Voice of Customer) 관련 메시지를 찾아냅니다.

class VOCAnalyzer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // VOC 관련 키워드
  static const List<String> vocKeywords = [
    '버그', '에러', '오류', '문제', '불편', '개선', '요청', '제안',
    '안돼', '안됨', '작동안함', '실행안됨', '느림', '늦음',
    '기능', '추가', '수정', '바꿔', '변경', '업데이트',
    '이상해', '이상함', '웹뷰', '지도', '검색', '로그인',
    '앱', '화면', '버튼', '클릭', '터치', '반응', '응답',
    '빠져나가', '나가짐', '꺼짐', '종료', '멈춤', '중단',
    '로딩', '기다림', '시간', '오래걸림', '카카오', '네이버',
    '구글', '소셜', '인증', '회원가입', '닉네임', '프로필'
  ];

  static Future<void> analyzeVOC() async {
    try {
      print('🔍 VOC 메시지 분석을 시작합니다...\n');
      
      // 모든 메시지 가져오기
      final QuerySnapshot snapshot = await _firestore
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(2000) // 최근 2000개 메시지
          .get();

      print('📊 총 ${snapshot.docs.length}개의 메시지를 분석 중...\n');

      List<Map<String, dynamic>> vocMessages = [];
      Map<String, int> meetingVOCCount = {};
      Map<String, Set<String>> vocKeywordUsage = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final content = data['content'] as String? ?? '';
        final messageType = data['type'] as String? ?? 'text';
        final meetingId = data['meetingId'] as String? ?? '';
        
        // 시스템 메시지 제외
        if (messageType == 'system') continue;
        
        final vocAnalysis = _analyzeMessage(content);
        
        if (vocAnalysis['isVOC'] as bool) {
          vocMessages.add({
            'id': doc.id,
            'meetingId': meetingId,
            'senderName': data['senderName'] ?? '',
            'content': content,
            'createdAt': data['createdAt'] as Timestamp?,
            'vocScore': vocAnalysis['score'],
            'detectedKeywords': vocAnalysis['keywords'],
            'category': vocAnalysis['category'],
            'urgency': vocAnalysis['urgency'],
          });
          
          // 모임별 VOC 카운트
          meetingVOCCount[meetingId] = (meetingVOCCount[meetingId] ?? 0) + 1;
          
          // 키워드 사용량 추적
          for (final keyword in vocAnalysis['keywords'] as List<String>) {
            vocKeywordUsage[keyword] = (vocKeywordUsage[keyword] ?? <String>{})..add(meetingId);
          }
        }
      }

      // 결과 출력
      print('📋 VOC 분석 결과');
      print('=' * 50);
      print('총 VOC 메시지: ${vocMessages.length}개');
      print('VOC가 발생한 모임: ${meetingVOCCount.length}개');
      print('');

      // 긴급도별 분류
      final urgentMessages = vocMessages.where((m) => m['urgency'] == 'HIGH').toList();
      final mediumMessages = vocMessages.where((m) => m['urgency'] == 'MEDIUM').toList();
      final lowMessages = vocMessages.where((m) => m['urgency'] == 'LOW').toList();

      print('🚨 긴급도별 분류');
      print('  긴급 (HIGH): ${urgentMessages.length}개');
      print('  보통 (MEDIUM): ${mediumMessages.length}개');
      print('  낮음 (LOW): ${lowMessages.length}개');
      print('');

      // 카테고리별 분류
      final categoryCount = <String, int>{};
      for (final message in vocMessages) {
        final category = message['category'] as String;
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      print('📊 카테고리별 분류');
      categoryCount.forEach((category, count) {
        print('  $category: $count개');
      });
      print('');

      // 가장 많은 VOC가 발생한 모임
      final sortedMeetings = meetingVOCCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      print('🎯 VOC 발생 상위 모임');
      for (int i = 0; i < 5 && i < sortedMeetings.length; i++) {
        final meeting = sortedMeetings[i];
        print('  모임 ${meeting.key}: ${meeting.value}개');
      }
      print('');

      // 자주 사용되는 VOC 키워드
      final keywordFrequency = <String, int>{};
      for (final entry in vocKeywordUsage.entries) {
        keywordFrequency[entry.key] = entry.value.length;
      }
      
      final sortedKeywords = keywordFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      print('🔑 자주 사용되는 VOC 키워드');
      for (int i = 0; i < 10 && i < sortedKeywords.length; i++) {
        final keyword = sortedKeywords[i];
        print('  "${keyword.key}": ${keyword.value}개 모임에서 사용');
      }
      print('');

      // 긴급 메시지 상세 출력
      if (urgentMessages.isNotEmpty) {
        print('🚨 긴급 처리 필요 메시지');
        print('=' * 50);
        
        for (int i = 0; i < 3 && i < urgentMessages.length; i++) {
          final message = urgentMessages[i];
          final createdAt = (message['createdAt'] as Timestamp?)?.toDate();
          
          print('${i + 1}. [${message['category']}] ${message['senderName']}');
          print('   모임: ${message['meetingId']}');
          print('   시간: ${createdAt?.toString().substring(0, 19) ?? '알 수 없음'}');
          print('   점수: ${message['vocScore']}');
          print('   키워드: ${(message['detectedKeywords'] as List).join(', ')}');
          print('   내용: ${message['content']}');
          print('');
        }
      }

      // 요약 리포트
      print('📝 요약 리포트');
      print('=' * 50);
      print('• 전체 메시지 중 ${((vocMessages.length / snapshot.docs.length) * 100).toStringAsFixed(1)}%가 VOC 관련');
      print('• 평균 VOC 점수: ${vocMessages.isNotEmpty ? (vocMessages.map((m) => m['vocScore'] as int).reduce((a, b) => a + b) / vocMessages.length).toStringAsFixed(1) : 0}');
      print('• 가장 빈번한 VOC 유형: ${categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key}');
      print('• 즉시 처리 필요: ${urgentMessages.length}개');

    } catch (e) {
      print('❌ VOC 분석 중 오류 발생: $e');
    }
  }

  static Map<String, dynamic> _analyzeMessage(String content) {
    final lowerContent = content.toLowerCase();
    int score = 0;
    List<String> detectedKeywords = [];
    String category = 'GENERAL';
    String urgency = 'LOW';

    // 키워드 매칭
    for (final keyword in vocKeywords) {
      if (lowerContent.contains(keyword.toLowerCase())) {
        score += 10;
        detectedKeywords.add(keyword);
      }
    }

    // 카테고리 분류
    if (lowerContent.contains('버그') || lowerContent.contains('에러') || lowerContent.contains('오류')) {
      category = 'BUG';
      score += 15;
    } else if (lowerContent.contains('기능') || lowerContent.contains('추가') || lowerContent.contains('개선')) {
      category = 'FEATURE_REQUEST';
      score += 10;
    } else if (lowerContent.contains('느림') || lowerContent.contains('늦음') || lowerContent.contains('로딩')) {
      category = 'PERFORMANCE';
      score += 12;
    } else if (lowerContent.contains('로그인') || lowerContent.contains('인증') || lowerContent.contains('회원가입')) {
      category = 'AUTH';
      score += 8;
    } else if (lowerContent.contains('지도') || lowerContent.contains('검색') || lowerContent.contains('웹뷰')) {
      category = 'UI_UX';
      score += 8;
    }

    // 감정 분석
    if (lowerContent.contains('안돼') || lowerContent.contains('안됨') || lowerContent.contains('작동안함')) {
      score += 20;
      urgency = 'HIGH';
    } else if (lowerContent.contains('불편') || lowerContent.contains('문제')) {
      score += 15;
      urgency = 'MEDIUM';
    }

    // 질문 패턴
    if (lowerContent.contains('?') || lowerContent.contains('어떻게') || lowerContent.contains('왜')) {
      score += 8;
    }

    // 길이 점수
    if (content.length > 100) score += 10;
    if (content.length > 200) score += 15;

    // 긴급도 결정
    if (score >= 50) urgency = 'HIGH';
    else if (score >= 25) urgency = 'MEDIUM';

    return {
      'isVOC': score >= 15, // 15점 이상이면 VOC로 분류
      'score': score,
      'keywords': detectedKeywords,
      'category': category,
      'urgency': urgency,
    };
  }
}

void main() async {
  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('🔥 Firebase 연결 성공!');
    
    // VOC 분석 실행
    await VOCAnalyzer.analyzeVOC();
    
  } catch (e) {
    print('❌ Firebase 초기화 실패: $e');
  }
}