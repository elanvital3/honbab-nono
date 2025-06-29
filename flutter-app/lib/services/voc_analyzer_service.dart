import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

class VOCAnalyzerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // VOC 키워드 목록
  static const List<String> _vocKeywords = [
    '버그', '에러', '오류', '문제', '불편', '개선', '요청', '제안',
    '안돼', '안됨', '작동안함', '실행안됨', '느림', '늦음',
    '기능', '추가', '수정', '바꿔', '변경', '업데이트',
    '이상해', '이상함', '웹뷰', '지도', '검색', '로그인',
    '앱', '화면', '버튼', '클릭', '터치', '반응', '응답',
    '빠져나가', '나가짐', '꺼짐', '종료', '멈춤', '중단',
    '로딩', '기다림', '시간', '오래걸림', '성가셔', '짜증',
    '이거뭐야', '뭐지', '왜안돼', '왜이래', '안되네', '실패'
  ];
  
  // 고임팩트 키워드 (높은 점수)
  static const List<String> _highImpactKeywords = [
    '버그', '에러', '오류', '꺼짐', '중단', '멈춤', '실패'
  ];
  
  // 중간임팩트 키워드
  static const List<String> _mediumImpactKeywords = [
    '문제', '불편', '느림', '안됨', '이상해', '짜증'
  ];

  // VOC 분석 결과 클래스
  static VOCAnalysis analyzeMessage(String content) {
    int score = 0;
    List<String> matchedKeywords = [];
    String category = 'GENERAL';
    
    // 키워드 매칭 및 점수 계산
    for (String keyword in _vocKeywords) {
      if (content.contains(keyword)) {
        score += _getKeywordScore(keyword);
        matchedKeywords.add(keyword);
      }
    }
    
    // 카테고리 분류
    if (content.contains('버그') || content.contains('에러') || 
        content.contains('오류') || content.contains('꺼짐')) {
      category = 'BUG';
      score += 10;
    } else if (content.contains('기능') || content.contains('추가') || 
               content.contains('요청') || content.contains('제안')) {
      category = 'FEATURE_REQUEST';
      score += 5;
    } else if (content.contains('느림') || content.contains('로딩') || 
               content.contains('오래걸림') || content.contains('시간')) {
      category = 'PERFORMANCE';
      score += 8;
    } else if (content.contains('로그인') || content.contains('인증')) {
      category = 'AUTH';
      score += 7;
    } else if (content.contains('화면') || content.contains('UI') || 
               content.contains('디자인') || content.contains('버튼')) {
      category = 'UI_UX';
      score += 6;
    }
    
    // 긴급도 계산
    String urgency = 'LOW';
    if (score >= 50) urgency = 'HIGH';
    else if (score >= 25) urgency = 'MEDIUM';
    
    return VOCAnalysis(
      score: score,
      category: category,
      urgency: urgency,
      keywords: matchedKeywords,
      isVOC: score >= 15,
    );
  }
  
  static int _getKeywordScore(String keyword) {
    if (_highImpactKeywords.contains(keyword)) return 20;
    if (_mediumImpactKeywords.contains(keyword)) return 15;
    return 10;
  }
  
  // Firebase에서 모든 메시지 분석
  static Future<VOCAnalysisResult> analyzeAllMessages({int limit = 1000}) async {
    try {
      if (kDebugMode) {
        print('🔍 VOC 분석 시작: 최근 $limit개 메시지 분석');
      }
      
      final snapshot = await _firestore
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      List<VOCMessage> vocMessages = [];
      List<Message> allMessages = [];
      
      for (var doc in snapshot.docs) {
        try {
          final message = Message.fromFirestore(doc);
          allMessages.add(message);
          
          // 시스템 메시지가 아닌 경우만 VOC 분석
          if (message.type != MessageType.system && message.content.isNotEmpty) {
            final analysis = analyzeMessage(message.content);
            
            if (analysis.isVOC) {
              vocMessages.add(VOCMessage(
                message: message,
                analysis: analysis,
              ));
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 메시지 파싱 실패: ${doc.id} - $e');
          }
        }
      }
      
      // 긴급도별로 정렬
      vocMessages.sort((a, b) {
        const urgencyOrder = {'HIGH': 3, 'MEDIUM': 2, 'LOW': 1};
        return (urgencyOrder[b.analysis.urgency] ?? 0) - 
               (urgencyOrder[a.analysis.urgency] ?? 0);
      });
      
      final result = VOCAnalysisResult(
        totalMessages: allMessages.length,
        vocMessages: vocMessages,
        statistics: _calculateStatistics(vocMessages),
        analyzedAt: DateTime.now(),
      );
      
      if (kDebugMode) {
        print('✅ VOC 분석 완료: ${vocMessages.length}개 VOC 발견');
      }
      
      return result;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ VOC 분석 실패: $e');
      }
      rethrow;
    }
  }
  
  static VOCStatistics _calculateStatistics(List<VOCMessage> vocMessages) {
    Map<String, int> urgencyCount = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0};
    Map<String, int> categoryCount = {};
    Map<String, int> keywordCount = {};
    
    for (var vocMsg in vocMessages) {
      final analysis = vocMsg.analysis;
      
      // 긴급도 카운트
      urgencyCount[analysis.urgency] = (urgencyCount[analysis.urgency] ?? 0) + 1;
      
      // 카테고리 카운트
      categoryCount[analysis.category] = (categoryCount[analysis.category] ?? 0) + 1;
      
      // 키워드 카운트
      for (String keyword in analysis.keywords) {
        keywordCount[keyword] = (keywordCount[keyword] ?? 0) + 1;
      }
    }
    
    return VOCStatistics(
      urgencyDistribution: urgencyCount,
      categoryDistribution: categoryCount,
      keywordFrequency: keywordCount,
    );
  }
  
  // VOC 투두 마크다운 생성
  static String generateVOCTodoMarkdown(VOCAnalysisResult result) {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    StringBuffer markdown = StringBuffer();
    
    // 헤더
    markdown.writeln('# 🎯 혼밥노노 VOC TODO List\\n');
    markdown.writeln('📅 **분석일시**: $timestamp');
    markdown.writeln('📊 **전체 메시지**: ${result.totalMessages}개');
    markdown.writeln('🎯 **VOC 메시지**: ${result.vocMessages.length}개\\n');
    
    // 통계 섹션
    markdown.writeln('## 📊 VOC 통계\\n');
    markdown.writeln('### 긴급도별 분포');
    markdown.writeln('- 🔥 긴급 (HIGH): ${result.statistics.urgencyDistribution['HIGH']}개');
    markdown.writeln('- ⚠️ 보통 (MEDIUM): ${result.statistics.urgencyDistribution['MEDIUM']}개');
    markdown.writeln('- 📝 낮음 (LOW): ${result.statistics.urgencyDistribution['LOW']}개\\n');
    
    markdown.writeln('### 카테고리별 분포');
    result.statistics.categoryDistribution.forEach((category, count) {
      final emoji = _getCategoryEmoji(category);
      markdown.writeln('- $emoji $category: ${count}개');
    });
    markdown.writeln('');
    
    markdown.writeln('### 주요 키워드 TOP 10');
    final sortedKeywords = result.statistics.keywordFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (int i = 0; i < 10 && i < sortedKeywords.length; i++) {
      final entry = sortedKeywords[i];
      markdown.writeln('${i + 1}. **${entry.key}**: ${entry.value}회');
    }
    markdown.writeln('');
    
    // 긴급도별 VOC 리스트
    for (String urgency in ['HIGH', 'MEDIUM', 'LOW']) {
      final urgencyMessages = result.vocMessages.where((msg) => msg.analysis.urgency == urgency).toList();
      if (urgencyMessages.isEmpty) continue;
      
      final urgencyEmoji = urgency == 'HIGH' ? '🔥' : urgency == 'MEDIUM' ? '⚠️' : '📝';
      markdown.writeln('## $urgencyEmoji $urgency 우선순위 (${urgencyMessages.length}개)\\n');
      
      for (int i = 0; i < urgencyMessages.length; i++) {
        final vocMsg = urgencyMessages[i];
        final msg = vocMsg.message;
        final analysis = vocMsg.analysis;
        final emoji = _getCategoryEmoji(analysis.category);
        final date = '${msg.createdAt.month}/${msg.createdAt.day}';
        
        markdown.writeln('### ${i + 1}. $emoji [${analysis.category}] ${analysis.score}점');
        markdown.writeln('- **날짜**: $date');
        markdown.writeln('- **작성자**: ${msg.senderName}');
        markdown.writeln('- **내용**: "${msg.content}"');
        markdown.writeln('- **키워드**: ${analysis.keywords.join(', ')}');
        markdown.writeln('- **상태**: [ ] 미처리');
        markdown.writeln('- **담당자**: [ ] 미지정');
        markdown.writeln('- **예상 작업시간**: [ ] 미정\\n');
      }
    }
    
    // 액션 플랜
    markdown.writeln('## 🎯 개선 액션 플랜\\n');
    
    final highPriorityItems = result.vocMessages.where((msg) => msg.analysis.urgency == 'HIGH').toList();
    markdown.writeln('### 🔥 즉시 처리 필요 (HIGH 우선순위)');
    if (highPriorityItems.isNotEmpty) {
      for (int i = 0; i < highPriorityItems.length; i++) {
        final msg = highPriorityItems[i];
        final preview = msg.message.content.length > 50 ? '${msg.message.content.substring(0, 50)}...' : msg.message.content;
        markdown.writeln('${i + 1}. **${msg.analysis.category}**: $preview');
        markdown.writeln('   - [ ] 원인 분석');
        markdown.writeln('   - [ ] 해결 방안 수립');
        markdown.writeln('   - [ ] 구현 및 테스트');
        markdown.writeln('   - [ ] 사용자 피드백 확인\\n');
      }
    } else {
      markdown.writeln('✅ 현재 긴급 처리 필요한 이슈 없음\\n');
    }
    
    final mediumPriorityItems = result.vocMessages.where((msg) => msg.analysis.urgency == 'MEDIUM').toList();
    markdown.writeln('### ⚠️ 단기 개선 계획 (MEDIUM 우선순위)');
    if (mediumPriorityItems.isNotEmpty) {
      markdown.writeln('- [ ] ${mediumPriorityItems.length}개 MEDIUM 우선순위 이슈 검토');
      markdown.writeln('- [ ] 개발 스프린트에 포함 여부 결정');
      markdown.writeln('- [ ] 우선순위 재조정\\n');
    } else {
      markdown.writeln('✅ 현재 MEDIUM 우선순위 이슈 없음\\n');
    }
    
    final lowPriorityItems = result.vocMessages.where((msg) => msg.analysis.urgency == 'LOW').toList();
    markdown.writeln('### 📝 장기 개선 계획 (LOW 우선순위)');
    if (lowPriorityItems.isNotEmpty) {
      markdown.writeln('- [ ] ${lowPriorityItems.length}개 LOW 우선순위 이슈 백로그 등록');
      markdown.writeln('- [ ] 사용자 요청 빈도 모니터링');
      markdown.writeln('- [ ] 장기 로드맵에 반영 검토\\n');
    } else {
      markdown.writeln('✅ 현재 LOW 우선순위 이슈 없음\\n');
    }
    
    // 푸터
    markdown.writeln('---');
    markdown.writeln('*이 리포트는 Firebase 채팅 메시지를 자동 분석하여 생성되었습니다.*');
    markdown.writeln('*VOC 분석 알고리즘: 키워드 기반 점수 시스템 + 카테고리 분류*');
    
    return markdown.toString();
  }
  
  static String _getCategoryEmoji(String category) {
    const emojiMap = {
      'BUG': '🐛',
      'FEATURE_REQUEST': '✨',
      'PERFORMANCE': '⚡',
      'AUTH': '🔐',
      'UI_UX': '🎨',
      'GENERAL': '📝'
    };
    return emojiMap[category] ?? '📝';
  }
}

// VOC 분석 결과 클래스들
class VOCAnalysis {
  final int score;
  final String category;
  final String urgency;
  final List<String> keywords;
  final bool isVOC;
  
  VOCAnalysis({
    required this.score,
    required this.category,
    required this.urgency,
    required this.keywords,
    required this.isVOC,
  });
}

class VOCMessage {
  final Message message;
  final VOCAnalysis analysis;
  
  VOCMessage({
    required this.message,
    required this.analysis,
  });
}

class VOCStatistics {
  final Map<String, int> urgencyDistribution;
  final Map<String, int> categoryDistribution;
  final Map<String, int> keywordFrequency;
  
  VOCStatistics({
    required this.urgencyDistribution,
    required this.categoryDistribution,
    required this.keywordFrequency,
  });
}

class VOCAnalysisResult {
  final int totalMessages;
  final List<VOCMessage> vocMessages;
  final VOCStatistics statistics;
  final DateTime analyzedAt;
  
  VOCAnalysisResult({
    required this.totalMessages,
    required this.vocMessages,
    required this.statistics,
    required this.analyzedAt,
  });
}