import 'dart:io';

/// 간단한 메시지 체크 스크립트
/// Firebase 콘솔에서 확인할 수 있는 정보를 정리합니다.

void main() {
  print('🔍 Firebase Firestore Messages 컬렉션 VOC 분석 가이드');
  print('=' * 60);
  print('');
  
  print('📋 1. Firebase 콘솔 접속 방법:');
  print('   - https://console.firebase.google.com/');
  print('   - 프로젝트: honbab-nono');
  print('   - Firestore Database > messages 컬렉션');
  print('');
  
  print('🔍 2. VOC 관련 키워드로 검색할 내용:');
  final vocKeywords = [
    '버그', '에러', '오류', '문제', '불편', '개선', '요청', '제안',
    '안돼', '안됨', '작동안함', '실행안됨', '느림', '늦음',
    '기능', '추가', '수정', '바꿔', '변경', '업데이트',
    '이상해', '이상함', '웹뷰', '지도', '검색', '로그인',
    '앱', '화면', '버튼', '클릭', '터치', '반응', '응답',
    '빠져나가', '나가짐', '꺼짐', '종료', '멈춤', '중단',
    '로딩', '기다림', '시간', '오래걸림'
  ];
  
  print('   주요 키워드:');
  for (int i = 0; i < vocKeywords.length; i++) {
    if (i % 5 == 0) print('   ');
    stdout.write('${vocKeywords[i].padRight(8)} ');
    if ((i + 1) % 5 == 0) print('');
  }
  print('\n');
  
  print('🎯 3. 확인해야 할 필드:');
  print('   - content (메시지 내용)');
  print('   - senderName (발신자명)');
  print('   - meetingId (모임 ID)');
  print('   - createdAt (생성 시간)');
  print('   - type (메시지 타입 - system 제외)');
  print('');
  
  print('📊 4. 분석 기준:');
  print('   - 긴급도 HIGH: 앱 오류, 기능 작동 안함');
  print('   - 긴급도 MEDIUM: 불편사항, 개선 요청');
  print('   - 긴급도 LOW: 일반적인 질문, 제안');
  print('');
  
  print('🔧 5. Flutter 앱에서 분석하는 방법:');
  print('   1. Flutter 앱 실행: flutter run');
  print('   2. 홈 화면에서 우상단 테스트 아이콘 클릭');
  print('   3. "VOC 메시지 분석" 버튼 클릭');
  print('   4. 결과 확인');
  print('');
  
  print('📝 6. 예상 VOC 카테고리:');
  final categories = {
    'BUG': '버그, 에러, 오류 관련',
    'FEATURE_REQUEST': '기능 추가, 개선 요청',
    'PERFORMANCE': '성능, 속도 관련 불만',
    'AUTH': '로그인, 인증 관련 문제',
    'UI_UX': '화면, 지도, 사용성 관련',
    'GENERAL': '일반적인 문의'
  };
  
  categories.forEach((key, value) {
    print('   $key: $value');
  });
  
  print('');
  print('✅ Firebase Test Screen을 사용하여 실제 데이터를 분석해보세요!');
}