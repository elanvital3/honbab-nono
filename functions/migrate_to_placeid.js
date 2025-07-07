/**
 * 기존 restaurants 데이터를 place_id 기반으로 마이그레이션
 * - Document ID를 place_id로 변경
 * - 중복 데이터 병합
 * - 새로운 구조로 변환
 */

const admin = require('firebase-admin');

// Firebase Admin 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

class RestaurantMigrator {
  constructor() {
    this.db = admin.firestore();
  }

  /**
   * 기존 데이터 백업
   */
  async backupExistingData() {
    console.log('📦 기존 데이터 백업 중...');
    
    const snapshot = await this.db.collection('restaurants').get();
    const backupData = [];
    
    snapshot.forEach(doc => {
      backupData.push({
        originalId: doc.id,
        data: doc.data()
      });
    });
    
    // 백업 컬렉션에 저장
    const backupBatch = this.db.batch();
    backupData.forEach((item, index) => {
      const backupRef = this.db.collection('restaurants_backup_2024').doc(`backup_${index}`);
      backupBatch.set(backupRef, {
        ...item,
        backupDate: admin.firestore.Timestamp.now()
      });
    });
    
    await backupBatch.commit();
    console.log(`✅ ${backupData.length}개 문서 백업 완료`);
    
    return backupData;
  }

  /**
   * place_id 기반으로 데이터 변환
   */
  transformToPlaceIdBased(originalData) {
    const placeIdMap = new Map();
    
    originalData.forEach(item => {
      const data = item.data;
      const placeId = data.placeId || data.id || item.originalId;
      
      // place_id가 없으면 스킵
      if (!placeId || placeId.length < 5) {
        console.log(`⚠️ 유효하지 않은 place_id: ${data.name}`);
        return;
      }
      
      // 새로운 구조로 변환
      const transformed = {
        placeId: placeId,
        name: data.name,
        address: data.address,
        roadAddress: data.roadAddress,
        latitude: data.latitude,
        longitude: data.longitude,
        phone: data.phone,
        category: data.category,
        kakaoCategory: data.kakaoCategory,
        url: data.url,
        imageUrl: data.imageUrl,
        
        // 유튜브 통계 (기본값 설정)
        youtubeStats: data.youtubeStats || {
          mentionCount: 1,
          channels: data.source === 'youtube_restaurant_crawler' ? ['유튜브 크롤러'] : [],
          firstMentionDate: data.crawledAt || data.createdAt || admin.firestore.Timestamp.now(),
          lastMentionDate: data.updatedAt || admin.firestore.Timestamp.now(),
          recentMentions: 0,
          representativeVideo: null
        },
        
        // 트렌드 점수 (기본값)
        trendScore: data.trendScore || {
          hotness: 50,
          consistency: 50,
          isRising: false,
          recentMentions: 0
        },
        
        // 태그 변환
        featureTags: this.convertTags(data),
        
        // 지역 정보
        region: data.region,
        province: data.province,
        city: data.city,
        
        // 메타데이터
        isActive: data.isActive !== false,
        isFeatured: data.isFeatured || false,
        source: data.source || 'migration',
        originalDocId: item.originalId,
        migratedAt: admin.firestore.Timestamp.now(),
        createdAt: data.createdAt || data.crawledAt || admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      };
      
      // 중복 체크 및 병합
      if (placeIdMap.has(placeId)) {
        const existing = placeIdMap.get(placeId);
        // 언급 횟수 증가
        existing.youtubeStats.mentionCount += 1;
        // 최신 정보로 업데이트
        if (data.updatedAt > existing.updatedAt) {
          placeIdMap.set(placeId, { ...existing, ...transformed });
        }
      } else {
        placeIdMap.set(placeId, transformed);
      }
    });
    
    return placeIdMap;
  }

  /**
   * 태그 변환
   */
  convertTags(data) {
    const tags = [];
    
    // 기존 featureTags가 있으면 사용
    if (data.featureTags && Array.isArray(data.featureTags)) {
      tags.push(...data.featureTags);
    }
    
    // 지역 태그 추가
    if (data.region === '제주도') {
      tags.push('#제주맛집');
    } else if (data.region === '서울') {
      tags.push('#서울맛집');
    } else if (data.region === '부산') {
      tags.push('#부산맛집');
    } else if (data.region === '경주') {
      tags.push('#경주맛집');
    }
    
    // 소스 기반 태그
    if (data.source === 'youtube_restaurant_crawler') {
      tags.push('#유튜버추천');
    }
    
    // 중복 제거
    return [...new Set(tags)].slice(0, 8);
  }

  /**
   * 새로운 구조로 저장
   */
  async saveNewStructure(placeIdMap) {
    console.log(`\n💾 place_id 기반으로 ${placeIdMap.size}개 맛집 저장 중...`);
    
    // 배치로 처리
    const batch = this.db.batch();
    let count = 0;
    
    for (const [placeId, data] of placeIdMap) {
      const docRef = this.db.collection('restaurants').doc(placeId);
      batch.set(docRef, data);
      count++;
      
      // 500개씩 배치 커밋
      if (count % 500 === 0) {
        await batch.commit();
        console.log(`   ✅ ${count}개 저장 완료...`);
      }
    }
    
    // 남은 문서 커밋
    if (count % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`✅ 총 ${count}개 문서 저장 완료`);
  }

  /**
   * 기존 문서 정리
   */
  async cleanupOldDocuments(backupData) {
    console.log('\n🧹 기존 문서 정리 중...');
    
    const placeIds = new Set();
    backupData.forEach(item => {
      const placeId = item.data.placeId || item.data.id;
      if (placeId) {
        placeIds.add(placeId);
      }
    });
    
    // place_id가 아닌 document ID를 가진 문서들 삭제
    const batch = this.db.batch();
    let deleteCount = 0;
    
    for (const item of backupData) {
      const docId = item.originalId;
      // document ID가 place_id가 아닌 경우만 삭제
      if (!placeIds.has(docId) || docId.length > 20) {
        const docRef = this.db.collection('restaurants').doc(docId);
        batch.delete(docRef);
        deleteCount++;
        
        if (deleteCount % 500 === 0) {
          await batch.commit();
        }
      }
    }
    
    if (deleteCount % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`✅ ${deleteCount}개 구문서 삭제 완료`);
  }

  /**
   * 마이그레이션 실행
   */
  async migrate() {
    try {
      console.log('🚀 Restaurant 데이터 place_id 기반 마이그레이션 시작!\n');
      
      // 1. 백업
      const backupData = await this.backupExistingData();
      
      // 2. 변환
      console.log('\n🔄 데이터 변환 중...');
      const placeIdMap = this.transformToPlaceIdBased(backupData);
      console.log(`✅ ${placeIdMap.size}개 고유 맛집으로 변환 완료`);
      
      // 3. 저장
      await this.saveNewStructure(placeIdMap);
      
      // 4. 정리
      await this.cleanupOldDocuments(backupData);
      
      console.log('\n🎉 마이그레이션 완료!');
      console.log(`   📊 원본: ${backupData.length}개 → 결과: ${placeIdMap.size}개`);
      console.log(`   🆔 모든 문서가 place_id를 Document ID로 사용`);
      console.log(`   📦 백업 컬렉션: restaurants_backup_2024`);
      
    } catch (error) {
      console.error('❌ 마이그레이션 실패:', error.message);
      throw error;
    }
  }

  /**
   * 마이그레이션 상태 확인
   */
  async checkMigrationStatus() {
    console.log('\n📊 마이그레이션 상태 확인...');
    
    const snapshot = await this.db.collection('restaurants').get();
    let placeIdCount = 0;
    let nonPlaceIdCount = 0;
    const samples = [];
    
    snapshot.forEach(doc => {
      const docId = doc.id;
      const data = doc.data();
      
      // place_id 형식 체크 (보통 8-10자리 숫자)
      if (/^\d{6,12}$/.test(docId)) {
        placeIdCount++;
        if (samples.length < 3) {
          samples.push({
            id: docId,
            name: data.name,
            hasYoutubeStats: !!data.youtubeStats
          });
        }
      } else {
        nonPlaceIdCount++;
      }
    });
    
    console.log(`\n✅ 전체 문서: ${snapshot.size}개`);
    console.log(`   - place_id 형식: ${placeIdCount}개`);
    console.log(`   - 기타 형식: ${nonPlaceIdCount}개`);
    
    if (samples.length > 0) {
      console.log('\n📋 샘플 데이터:');
      samples.forEach(sample => {
        console.log(`   - ID: ${sample.id}, 이름: ${sample.name}, 유튜브통계: ${sample.hasYoutubeStats ? '✓' : '✗'}`);
      });
    }
  }
}

// 직접 실행
if (require.main === module) {
  async function run() {
    const migrator = new RestaurantMigrator();
    
    // 상태 확인
    await migrator.checkMigrationStatus();
    
    // 마이그레이션 실행 여부 확인
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    readline.question('\n마이그레이션을 실행하시겠습니까? (y/n): ', async (answer) => {
      if (answer.toLowerCase() === 'y') {
        await migrator.migrate();
      } else {
        console.log('마이그레이션 취소됨');
      }
      readline.close();
      process.exit(0);
    });
  }
  
  run().catch(console.error);
}

module.exports = RestaurantMigrator;