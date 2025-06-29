const admin = require('firebase-admin');
const fs = require('fs');

// Firebase Admin SDK 초기화
const serviceAccount = require('./honbab-nono-firebase-adminsdk.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// VOC 키워드 목록
const vocKeywords = [
  '버그', '에러', '오류', '문제', '불편', '개선', '요청', '제안',
  '안돼', '안됨', '작동안함', '실행안됨', '느림', '늦음',
  '기능', '추가', '수정', '바꿔', '변경', '업데이트',
  '이상해', '이상함', '웹뷰', '지도', '검색', '로그인',
  '앱', '화면', '버튼', '클릭', '터치', '반응', '응답',
  '빠져나가', '나가짐', '꺼짐', '종료', '멈춤', '중단',
  '로딩', '기다림', '시간', '오래걸림', '성가셔', '짜증',
  '이거뭐야', '뭐지', '왜안돼', '왜이래', '안되네', '실패'
];

// VOC 분석 함수
function analyzeVOC(content) {
  let score = 0;
  let matchedKeywords = [];
  let category = 'GENERAL';
  
  // 키워드 매칭
  vocKeywords.forEach(keyword => {
    if (content.includes(keyword)) {
      score += getKeywordScore(keyword);
      matchedKeywords.push(keyword);
    }
  });
  
  // 카테고리 분류
  if (content.includes('버그') || content.includes('에러') || content.includes('오류') || content.includes('꺼짐')) {
    category = 'BUG';
    score += 10;
  } else if (content.includes('기능') || content.includes('추가') || content.includes('요청')) {
    category = 'FEATURE_REQUEST';
    score += 5;
  } else if (content.includes('느림') || content.includes('로딩') || content.includes('오래걸림')) {
    category = 'PERFORMANCE';
    score += 8;
  } else if (content.includes('로그인') || content.includes('인증')) {
    category = 'AUTH';
    score += 7;
  } else if (content.includes('화면') || content.includes('UI') || content.includes('디자인')) {
    category = 'UI_UX';
    score += 6;
  }
  
  // 긴급도 계산
  let urgency = 'LOW';
  if (score >= 50) urgency = 'HIGH';
  else if (score >= 25) urgency = 'MEDIUM';
  
  return {
    score,
    category,
    urgency,
    keywords: matchedKeywords,
    isVOC: score >= 15
  };
}

function getKeywordScore(keyword) {
  const highImpactKeywords = ['버그', '에러', '오류', '꺼짐', '중단', '멈춤'];
  const mediumImpactKeywords = ['문제', '불편', '느림', '안됨', '실패'];
  
  if (highImpactKeywords.includes(keyword)) return 20;
  if (mediumImpactKeywords.includes(keyword)) return 15;
  return 10;
}

// 메인 분석 함수
async function analyzeVOCFromFirestore() {
  try {
    console.log('🔍 Firestore에서 메시지 수집 중...');
    
    // 최근 500개 메시지 가져오기
    const messagesRef = db.collection('messages');
    const snapshot = await messagesRef
      .orderBy('createdAt', 'desc')
      .limit(500)
      .get();
    
    console.log(`📊 총 ${snapshot.size}개 메시지 발견`);
    
    const vocMessages = [];
    const allMessages = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const message = {
        id: doc.id,
        meetingId: data.meetingId,
        senderId: data.senderId,
        senderName: data.senderName,
        content: data.content,
        type: data.type || 'text',
        createdAt: data.createdAt?.toDate() || new Date(),
        ...data
      };
      
      allMessages.push(message);
      
      // 시스템 메시지가 아닌 경우만 VOC 분석
      if (data.type !== 'system' && data.content) {
        const analysis = analyzeVOC(data.content);
        
        if (analysis.isVOC) {
          vocMessages.push({
            ...message,
            vocAnalysis: analysis
          });
        }
      }
    });
    
    console.log(`🎯 VOC 메시지 ${vocMessages.length}개 발견`);
    
    // VOC 메시지를 긴급도별로 정렬
    vocMessages.sort((a, b) => {
      const urgencyOrder = { 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1 };
      return urgencyOrder[b.vocAnalysis.urgency] - urgencyOrder[a.vocAnalysis.urgency];
    });
    
    // VOC TODO 마크다운 생성
    generateVOCTodoMarkdown(vocMessages, allMessages);
    
    return vocMessages;
    
  } catch (error) {
    console.error('❌ VOC 분석 실패:', error);
    return [];
  }
}

// VOC TODO 마크다운 파일 생성
function generateVOCTodoMarkdown(vocMessages, allMessages) {
  const now = new Date();
  const timestamp = now.toLocaleString('ko-KR');
  
  let markdown = `# 🎯 혼밥노노 VOC TODO List\n\n`;
  markdown += `📅 **분석일시**: ${timestamp}\n`;
  markdown += `📊 **전체 메시지**: ${allMessages.length}개\n`;
  markdown += `🎯 **VOC 메시지**: ${vocMessages.length}개\n\n`;
  
  // 통계 섹션
  const stats = getVOCStatistics(vocMessages);
  markdown += `## 📊 VOC 통계\n\n`;
  markdown += `### 긴급도별 분포\n`;
  markdown += `- 🔥 긴급 (HIGH): ${stats.urgency.HIGH}개\n`;
  markdown += `- ⚠️ 보통 (MEDIUM): ${stats.urgency.MEDIUM}개\n`;
  markdown += `- 📝 낮음 (LOW): ${stats.urgency.LOW}개\n\n`;
  
  markdown += `### 카테고리별 분포\n`;
  Object.entries(stats.category).forEach(([cat, count]) => {
    const emoji = getCategoryEmoji(cat);
    markdown += `- ${emoji} ${cat}: ${count}개\n`;
  });
  markdown += '\n';
  
  // 긴급도별 VOC 리스트
  ['HIGH', 'MEDIUM', 'LOW'].forEach(urgency => {
    const urgencyMessages = vocMessages.filter(msg => msg.vocAnalysis.urgency === urgency);
    if (urgencyMessages.length === 0) return;
    
    const urgencyEmoji = urgency === 'HIGH' ? '🔥' : urgency === 'MEDIUM' ? '⚠️' : '📝';
    markdown += `## ${urgencyEmoji} ${urgency} 우선순위 (${urgencyMessages.length}개)\n\n`;
    
    urgencyMessages.forEach((msg, index) => {
      const analysis = msg.vocAnalysis;
      const emoji = getCategoryEmoji(analysis.category);
      const date = msg.createdAt.toLocaleDateString('ko-KR');
      
      markdown += `### ${emoji} [${analysis.category}] ${analysis.score}점\n`;
      markdown += `- **날짜**: ${date}\n`;
      markdown += `- **작성자**: ${msg.senderName}\n`;
      markdown += `- **내용**: "${msg.content}"\n`;
      markdown += `- **키워드**: ${analysis.keywords.join(', ')}\n`;
      markdown += `- **상태**: [ ] 미처리\n`;
      markdown += `- **담당자**: [ ] 미지정\n`;
      markdown += `- **예상 작업시간**: [ ] 미정\n\n`;
    });
  });
  
  // 개선 액션 플랜
  markdown += `## 🎯 개선 액션 플랜\n\n`;
  markdown += `### 즉시 처리 필요 (HIGH 우선순위)\n`;
  const highPriorityItems = vocMessages.filter(msg => msg.vocAnalysis.urgency === 'HIGH');
  if (highPriorityItems.length > 0) {
    highPriorityItems.forEach((msg, index) => {
      markdown += `${index + 1}. **${msg.vocAnalysis.category}**: ${msg.content.substring(0, 50)}...\n`;
      markdown += `   - [ ] 원인 분석\n`;
      markdown += `   - [ ] 해결 방안 수립\n`;
      markdown += `   - [ ] 구현 및 테스트\n`;
      markdown += `   - [ ] 사용자 피드백 확인\n\n`;
    });
  } else {
    markdown += `✅ 현재 긴급 처리 필요한 이슈 없음\n\n`;
  }
  
  markdown += `### 단기 개선 계획 (MEDIUM 우선순위)\n`;
  const mediumPriorityItems = vocMessages.filter(msg => msg.vocAnalysis.urgency === 'MEDIUM');
  if (mediumPriorityItems.length > 0) {
    markdown += `- [ ] ${mediumPriorityItems.length}개 MEDIUM 우선순위 이슈 검토\n`;
    markdown += `- [ ] 개발 스프린트에 포함 여부 결정\n`;
    markdown += `- [ ] 우선순위 재조정\n\n`;
  }
  
  markdown += `### 장기 개선 계획 (LOW 우선순위)\n`;
  const lowPriorityItems = vocMessages.filter(msg => msg.vocAnalysis.urgency === 'LOW');
  if (lowPriorityItems.length > 0) {
    markdown += `- [ ] ${lowPriorityItems.length}개 LOW 우선순위 이슈 백로그 등록\n`;
    markdown += `- [ ] 사용자 요청 빈도 모니터링\n`;
    markdown += `- [ ] 장기 로드맵에 반영 검토\n\n`;
  }
  
  // 푸터
  markdown += `---\n`;
  markdown += `*이 리포트는 Firebase 채팅 메시지를 자동 분석하여 생성되었습니다.*\n`;
  markdown += `*VOC 분석 알고리즘: 키워드 기반 점수 시스템 + 카테고리 분류*\n`;
  
  // 파일 저장
  const filename = `VOC_TODO_${now.getFullYear()}${(now.getMonth()+1).toString().padStart(2,'0')}${now.getDate().toString().padStart(2,'0')}.md`;
  fs.writeFileSync(filename, markdown, 'utf8');
  
  console.log(`✅ VOC TODO 파일 생성 완료: ${filename}`);
  console.log(`📄 총 ${vocMessages.length}개 VOC 이슈가 정리되었습니다.`);
}

// VOC 통계 계산
function getVOCStatistics(vocMessages) {
  const stats = {
    urgency: { HIGH: 0, MEDIUM: 0, LOW: 0 },
    category: {}
  };
  
  vocMessages.forEach(msg => {
    const analysis = msg.vocAnalysis;
    stats.urgency[analysis.urgency]++;
    stats.category[analysis.category] = (stats.category[analysis.category] || 0) + 1;
  });
  
  return stats;
}

// 카테고리 이모지 반환
function getCategoryEmoji(category) {
  const emojiMap = {
    'BUG': '🐛',
    'FEATURE_REQUEST': '✨',
    'PERFORMANCE': '⚡',
    'AUTH': '🔐',
    'UI_UX': '🎨',
    'GENERAL': '📝'
  };
  return emojiMap[category] || '📝';
}

// 실행
if (require.main === module) {
  analyzeVOCFromFirestore()
    .then(vocMessages => {
      console.log('\n🎉 VOC 분석 완료!');
      console.log(`총 ${vocMessages.length}개의 VOC 이슈가 발견되었습니다.`);
      process.exit(0);
    })
    .catch(error => {
      console.error('❌ 분석 실패:', error);
      process.exit(1);
    });
}