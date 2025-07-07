import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/restaurant.dart';

// 제주도 Google Places 데이터 업데이트 스크립트
class JejuPlacesUpdater {
  static const String _baseUrl = 'https://places.googleapis.com/v1/places:searchText';
  static String get _apiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> updateJejuRestaurants() async {
    print('🏝️ 제주도 Google Places 데이터 업데이트 시작...\n');
    
    try {
      if (_apiKey.isEmpty) {
        print('❌ Google Places API 키가 설정되지 않았습니다.');
        return;
      }
      
      // 제주도 기존 맛집 데이터 조회
      final existingRestaurants = await _getExistingJejuRestaurants();
      print('📊 기존 제주도 맛집: ${existingRestaurants.length}개\n');
      
      if (existingRestaurants.isEmpty) {
        print('❌ 기존 제주도 맛집 데이터가 없습니다.');
        return;
      }
      
      // 모든 제주도 맛집 업데이트 (31개)
      final restaurantsToUpdate = existingRestaurants;
      
      int updateCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < restaurantsToUpdate.length; i++) {
        final restaurant = restaurantsToUpdate[i];
        print('🔍 [${i + 1}/${restaurantsToUpdate.length}] ${restaurant['name']} 업데이트 중...');
        
        try {
          // Google Places에서 최신 데이터 검색
          final googleData = await _searchGooglePlaces(restaurant['name'], '제주도');
          
          if (googleData != null) {
            // Firestore 업데이트
            await _updateRestaurantData(restaurant['id'], googleData);
            updateCount++;
            
            final photoCount = googleData['googlePlaces']['photos']?.length ?? 0;
            final hasOpeningHours = googleData['googlePlaces']['regularOpeningHours'] != null;
            print('   ✅ 업데이트 완료 (사진: ${photoCount}장, 영업시간: ${hasOpeningHours ? 'O' : 'X'})');
          } else {
            print('   ⚠️ Google Places에서 찾을 수 없음');
            errorCount++;
          }
          
          // API 제한 방지
          await Future.delayed(Duration(milliseconds: 2000));
          
        } catch (e) {
          print('   ❌ 업데이트 실패: $e');
          errorCount++;
        }
      }
      
      print('\n🎯 제주도 업데이트 완료!');
      print('   ✅ 성공: ${updateCount}개');
      print('   ❌ 실패: ${errorCount}개');
      print('   📸 업데이트된 맛집들이 최대 10장 사진을 가집니다!');
      print('   🕒 상세 영업시간 정보도 추가되었습니다!');
      
    } catch (e) {
      print('❌ 전체 프로세스 오류: $e');
    }
  }
  
  // 기존 제주도 맛집 데이터 조회
  static Future<List<Map<String, dynamic>>> _getExistingJejuRestaurants() async {
    try {
      final query = await _firestore
          .collection('restaurants')
          .where('region', isEqualTo: '제주도')
          .limit(50)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'],
        'address': doc.data()['address'] ?? '',
        'latitude': doc.data()['latitude'],
        'longitude': doc.data()['longitude'],
      }).toList();
      
    } catch (e) {
      print('❌ Firestore 조회 오류: $e');
      return [];
    }
  }
  
  // Google Places API 검색
  static Future<Map<String, dynamic>?> _searchGooglePlaces(String restaurantName, String region) async {
    try {
      final requestBody = {
        'textQuery': '$restaurantName $region',
        'includedType': 'restaurant',
        'maxResultCount': 1,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': 33.4996,
              'longitude': 126.5312
            },
            'radius': 25000.0 // 25km 반경
          }
        },
        'languageCode': 'ko',
        'regionCode': 'KR'
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.types,places.photos,places.currentOpeningHours,places.regularOpeningHours,places.reviews,places.nationalPhoneNumber'
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List? ?? [];
        
        if (places.isNotEmpty) {
          return _parseGooglePlaceData(places.first);
        } else {
          print('   📍 검색 결과 없음');
        }
      } else {
        print('   ⚠️ API 오류: ${response.statusCode}');
        if (response.statusCode == 400) {
          print('   📋 응답: ${response.body}');
        }
      }
      
      return null;
    } catch (e) {
      print('   ❌ API 호출 오류: $e');
      return null;
    }
  }
  
  // Google Places 데이터 파싱
  static Map<String, dynamic> _parseGooglePlaceData(Map<String, dynamic> place) {
    final photos = place['photos'] as List? ?? [];
    final photoUrls = <String>[];
    
    // 최대 10장 사진 URL 생성
    for (final photo in photos.take(10)) {
      final photoName = photo['name'] as String?;
      if (photoName != null) {
        final photoUrl = 'https://places.googleapis.com/v1/$photoName/media?maxHeightPx=400&maxWidthPx=600&key=$_apiKey';
        photoUrls.add(photoUrl);
      }
    }
    
    // 리뷰 데이터 파싱 (최대 5개) - GoogleReview 모델과 호환되도록
    final reviews = place['reviews'] as List? ?? [];
    final reviewData = reviews.take(5).map((review) {
      // publishTime을 Unix timestamp로 변환
      int timeStamp = 0;
      try {
        final publishTime = review['publishTime'] as String?;
        if (publishTime != null && publishTime.isNotEmpty) {
          final dateTime = DateTime.parse(publishTime);
          timeStamp = dateTime.millisecondsSinceEpoch ~/ 1000; // 초 단위로 변환
        }
      } catch (e) {
        print('⚠️ 리뷰 시간 파싱 오류: $e');
      }
      
      return {
        'author_name': review['authorAttribution']?['displayName'] ?? 'Anonymous', // 올바른 필드명
        'rating': review['rating'] ?? 5,
        'text': review['text']?['text'] ?? '',
        'time': timeStamp, // Unix timestamp (초)
        'profile_photo_url': review['authorAttribution']?['photoUri'],
      };
    }).toList();
    
    return {
      'googlePlaces': {
        'placeId': place['id'],
        'rating': (place['rating'] as num?)?.toDouble(),
        'userRatingsTotal': place['userRatingCount'] ?? 0,
        'reviews': reviewData,
        'photos': photoUrls,
        'priceLevel': place['priceLevel'],
        'isOpen': place['currentOpeningHours']?['openNow'],
        'phoneNumber': place['nationalPhoneNumber'],
        'regularOpeningHours': place['regularOpeningHours'],
        'updatedAt': Timestamp.now(),
      },
      'imageUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
      'updatedAt': Timestamp.now(),
    };
  }
  
  // Firestore 데이터 업데이트
  static Future<void> _updateRestaurantData(String docId, Map<String, dynamic> googleData) async {
    try {
      await _firestore
          .collection('restaurants')
          .doc(docId)
          .update(googleData);
    } catch (e) {
      throw Exception('Firestore 업데이트 실패: $e');
    }
  }
}