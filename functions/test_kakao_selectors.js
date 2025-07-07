/**
 * 카카오맵 현재 선택자 테스트
 * - 실제 카카오맵 페이지에서 평점 선택자 확인
 */

const axios = require('axios');
const cheerio = require('cheerio');

// 환경변수에서 API 키 로드
require('dotenv').config({ path: '../flutter-app/.env' });

async function testKakaoSelectors() {
  try {
    console.log('🔍 카카오맵 페이지 구조 분석 중...\n');
    
    // 명동교자 본점 페이지
    const testUrl = 'http://place.map.kakao.com/10332413';
    
    const response = await axios.get(testUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
      timeout: 15000
    });

    const $ = cheerio.load(response.data);
    
    console.log('📄 페이지 로드 성공');
    console.log(`📏 페이지 크기: ${response.data.length} bytes\n`);
    
    // 현재 사용 중인 선택자들 테스트
    console.log('🧪 기존 선택자 테스트:');
    const oldSelectors = [
      '.grade_star .num_rate',
      '.score_star .num_rate',
      '.rating_star .num_rate',
      '.grade .num_rate'
    ];
    
    for (const selector of oldSelectors) {
      const element = $(selector);
      if (element.length > 0) {
        console.log(`✅ ${selector}: "${element.text().trim()}"`);
      } else {
        console.log(`❌ ${selector}: 요소 없음`);
      }
    }
    
    console.log('\n🔍 모든 평점 관련 클래스 찾기:');
    
    // 평점과 관련된 모든 클래스 찾기
    const ratingClasses = [];
    $('*').each((i, elem) => {
      const className = $(elem).attr('class');
      if (className) {
        const classes = className.split(' ');
        classes.forEach(cls => {
          if (cls.includes('rate') || cls.includes('score') || cls.includes('grade') || cls.includes('star')) {
            if (!ratingClasses.includes(cls)) {
              ratingClasses.push(cls);
            }
          }
        });
      }
    });
    
    console.log('평점 관련 클래스들:', ratingClasses);
    
    console.log('\n🔍 숫자 패턴 검색:');
    // 페이지에서 평점처럼 보이는 숫자 패턴 찾기
    const ratingPattern = /[0-9]\.[0-9]/g;
    const matches = response.data.match(ratingPattern) || [];
    const uniqueRatings = [...new Set(matches)];
    console.log('발견된 평점 형태 숫자들:', uniqueRatings);
    
    console.log('\n🔍 JSON 데이터 패턴 검색:');
    // JSON 내부에서 평점 데이터 찾기
    const jsonPatterns = [
      /"rating":\s*"?([0-9.]+)"?/g,
      /"score":\s*"?([0-9.]+)"?/g,
      /"grade":\s*"?([0-9.]+)"?/g,
      /"starRating":\s*"?([0-9.]+)"?/g
    ];
    
    for (const pattern of jsonPatterns) {
      const matches = [...response.data.matchAll(pattern)];
      if (matches.length > 0) {
        console.log(`JSON 패턴 발견: ${matches[0][0]} -> ${matches[0][1]}`);
      }
    }
    
    console.log('\n🔍 메타 태그 확인:');
    // 메타 태그에서 평점 정보 찾기
    $('meta').each((i, elem) => {
      const property = $(elem).attr('property');
      const content = $(elem).attr('content');
      if (property && (property.includes('rating') || property.includes('score'))) {
        console.log(`메타 태그: ${property} = ${content}`);
      }
    });
    
    console.log('\n🔍 스크립트 태그 분석:');
    // script 태그 내용에서 평점 데이터 찾기
    $('script').each((i, elem) => {
      const scriptContent = $(elem).html();
      if (scriptContent && scriptContent.includes('rating')) {
        const lines = scriptContent.split('\n');
        lines.forEach((line, lineNum) => {
          if (line.includes('rating') && line.includes(':')) {
            console.log(`스크립트 ${i+1}, 라인 ${lineNum+1}: ${line.trim()}`);
          }
        });
      }
    });
    
  } catch (error) {
    console.error('❌ 테스트 오류:', error.message);
  }
}

// 실행
if (require.main === module) {
  testKakaoSelectors().catch(console.error);
}

module.exports = testKakaoSelectors;