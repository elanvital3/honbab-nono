import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

class LocationService {
  static final Location _location = Location();
  static LocationData? _currentLocation;
  
  // 계층적 위치 데이터 (도/특별시 → 시/군)
  static const Map<String, Map<String, Map<String, double>>> hierarchicalLocations = {
    '서울특별시': {
      '서울시': {'lat': 37.5665, 'lng': 126.9780},
    },
    '부산광역시': {
      '부산시': {'lat': 35.1796, 'lng': 129.0756},
    },
    '대구광역시': {
      '대구시': {'lat': 35.8714, 'lng': 128.6014},
    },
    '인천광역시': {
      '인천시': {'lat': 37.4563, 'lng': 126.7052},
    },
    '광주광역시': {
      '광주시': {'lat': 35.1595, 'lng': 126.8526},
    },
    '대전광역시': {
      '대전시': {'lat': 36.3504, 'lng': 127.3845},
    },
    '울산광역시': {
      '울산시': {'lat': 35.5384, 'lng': 129.3114},
    },
    '세종특별자치시': {
      '세종시': {'lat': 36.4800, 'lng': 127.2890},
    },
    '경기도': {
      '수원시': {'lat': 37.2636, 'lng': 127.0286},
      '성남시': {'lat': 37.4201, 'lng': 127.1262},
      '안양시': {'lat': 37.3943, 'lng': 126.9568},
      '안산시': {'lat': 37.3236, 'lng': 126.8219},
      '고양시': {'lat': 37.6584, 'lng': 126.8320},
      '용인시': {'lat': 37.2410, 'lng': 127.1776},
      '부천시': {'lat': 37.5036, 'lng': 126.7660},
      '화성시': {'lat': 37.1999, 'lng': 126.831},
      '남양주시': {'lat': 37.6369, 'lng': 127.2165},
      '평택시': {'lat': 36.9922, 'lng': 127.1127},
    },
    '강원특별자치도': {
      '춘천시': {'lat': 37.8813, 'lng': 127.7298},
      '원주시': {'lat': 37.3422, 'lng': 127.9202},
      '강릉시': {'lat': 37.7519, 'lng': 128.8761},
      '동해시': {'lat': 37.5247, 'lng': 129.1143},
      '태백시': {'lat': 37.1640, 'lng': 128.9856},
      '속초시': {'lat': 38.2070, 'lng': 128.5918},
      '삼척시': {'lat': 37.4502, 'lng': 129.1655},
    },
    '충청북도': {
      '청주시': {'lat': 36.6424, 'lng': 127.4890},
      '충주시': {'lat': 36.9910, 'lng': 127.9259},
      '제천시': {'lat': 37.1326, 'lng': 128.1907},
      '보은군': {'lat': 36.4895, 'lng': 127.7295},
      '옥천군': {'lat': 36.3062, 'lng': 127.5718},
      '영동군': {'lat': 36.1751, 'lng': 127.7834},
      '증평군': {'lat': 36.7848, 'lng': 127.5814},
      '진천군': {'lat': 36.8557, 'lng': 127.4335},
      '괴산군': {'lat': 36.8155, 'lng': 127.7875},
      '음성군': {'lat': 36.9394, 'lng': 127.6858},
      '단양군': {'lat': 36.9845, 'lng': 128.3656},
    },
    '충청남도': {
      '천안시': {'lat': 36.8151, 'lng': 127.1139},
      '공주시': {'lat': 36.4465, 'lng': 127.1189},
      '보령시': {'lat': 36.3331, 'lng': 126.6127},
      '아산시': {'lat': 36.7898, 'lng': 127.0020},
      '서산시': {'lat': 36.7848, 'lng': 126.4503},
      '논산시': {'lat': 36.1873, 'lng': 127.0986},
      '계룡시': {'lat': 36.2743, 'lng': 127.2486},
      '당진시': {'lat': 36.8926, 'lng': 126.6277},
      '금산군': {'lat': 36.1089, 'lng': 127.4881},
      '부여군': {'lat': 36.2756, 'lng': 126.9099},
      '서천군': {'lat': 36.0819, 'lng': 126.6914},
      '청양군': {'lat': 36.4594, 'lng': 126.8023},
      '홍성군': {'lat': 36.6015, 'lng': 126.6607},
      '예산군': {'lat': 36.6826, 'lng': 126.8507},
      '태안군': {'lat': 36.7455, 'lng': 126.2980},
    },
    '전라북도': {
      '전주시': {'lat': 35.8242, 'lng': 127.1480},
      '군산시': {'lat': 35.9676, 'lng': 126.7369},
      '익산시': {'lat': 35.9483, 'lng': 126.9576},
      '정읍시': {'lat': 35.5699, 'lng': 126.8558},
      '남원시': {'lat': 35.4164, 'lng': 127.3905},
      '김제시': {'lat': 35.8037, 'lng': 126.8805},
      '완주군': {'lat': 35.9056, 'lng': 127.1651},
      '진안군': {'lat': 35.7917, 'lng': 127.4249},
      '무주군': {'lat': 36.0073, 'lng': 127.6613},
      '장수군': {'lat': 35.6475, 'lng': 127.5197},
      '임실군': {'lat': 35.6176, 'lng': 127.2895},
      '순창군': {'lat': 35.3746, 'lng': 127.1372},
      '고창군': {'lat': 35.4351, 'lng': 126.7017},
      '부안군': {'lat': 35.7318, 'lng': 126.7330},
    },
    '전라남도': {
      '목포시': {'lat': 34.8118, 'lng': 126.3922},
      '여수시': {'lat': 34.7604, 'lng': 127.6622},
      '순천시': {'lat': 34.9507, 'lng': 127.4872},
      '나주시': {'lat': 35.0160, 'lng': 126.7108},
      '광양시': {'lat': 34.9407, 'lng': 127.5956},
      '담양군': {'lat': 35.3211, 'lng': 126.9882},
      '곡성군': {'lat': 35.2819, 'lng': 127.2916},
      '구례군': {'lat': 35.2020, 'lng': 127.4632},
      '고흥군': {'lat': 34.6114, 'lng': 127.2858},
      '보성군': {'lat': 34.7713, 'lng': 127.0801},
      '화순군': {'lat': 35.0647, 'lng': 126.9864},
      '장흥군': {'lat': 34.6813, 'lng': 126.9066},
      '강진군': {'lat': 34.6420, 'lng': 126.7677},
      '해남군': {'lat': 34.5732, 'lng': 126.5989},
      '영암군': {'lat': 34.8005, 'lng': 126.6968},
      '무안군': {'lat': 34.9900, 'lng': 126.4819},
      '함평군': {'lat': 35.0663, 'lng': 126.5168},
      '영광군': {'lat': 35.2772, 'lng': 126.5122},
      '장성군': {'lat': 35.3017, 'lng': 126.7856},
      '완도군': {'lat': 34.3105, 'lng': 126.7552},
      '진도군': {'lat': 34.4870, 'lng': 126.2639},
      '신안군': {'lat': 34.8276, 'lng': 126.1067},
    },
    '경상북도': {
      '포항시': {'lat': 36.0190, 'lng': 129.3435},
      '경주시': {'lat': 35.8562, 'lng': 129.2247},
      '김천시': {'lat': 36.1396, 'lng': 128.1136},
      '안동시': {'lat': 36.5684, 'lng': 128.7294},
      '구미시': {'lat': 36.1196, 'lng': 128.3440},
      '영주시': {'lat': 36.8056, 'lng': 128.6239},
      '영천시': {'lat': 35.9733, 'lng': 128.9386},
      '상주시': {'lat': 36.4107, 'lng': 128.1590},
      '문경시': {'lat': 36.5867, 'lng': 128.1867},
      '경산시': {'lat': 35.8251, 'lng': 128.7411},
      '군위군': {'lat': 36.2395, 'lng': 128.5741},
      '의성군': {'lat': 36.3526, 'lng': 128.6976},
      '청송군': {'lat': 36.4357, 'lng': 129.0570},
      '영양군': {'lat': 36.6696, 'lng': 129.1126},
      '영덕군': {'lat': 36.4153, 'lng': 129.3656},
      '청도군': {'lat': 35.6477, 'lng': 128.7359},
      '고령군': {'lat': 35.7276, 'lng': 128.2632},
      '성주군': {'lat': 35.9198, 'lng': 128.2829},
      '칠곡군': {'lat': 35.9943, 'lng': 128.4017},
      '예천군': {'lat': 36.6547, 'lng': 128.4517},
      '봉화군': {'lat': 36.8932, 'lng': 128.7325},
      '울진군': {'lat': 36.9930, 'lng': 129.4006},
      '울릉군': {'lat': 37.4845, 'lng': 130.9057},
    },
    '경상남도': {
      '창원시': {'lat': 35.2281, 'lng': 128.6811},
      '진주시': {'lat': 35.1800, 'lng': 128.1076},
      '통영시': {'lat': 34.8544, 'lng': 128.4331},
      '사천시': {'lat': 35.0036, 'lng': 128.0644},
      '김해시': {'lat': 35.2285, 'lng': 128.8890},
      '밀양시': {'lat': 35.5040, 'lng': 128.7460},
      '거제시': {'lat': 34.8807, 'lng': 128.6213},
      '양산시': {'lat': 35.3350, 'lng': 129.0377},
      '의령군': {'lat': 35.3224, 'lng': 128.2618},
      '함안군': {'lat': 35.2726, 'lng': 128.4063},
      '창녕군': {'lat': 35.5444, 'lng': 128.4924},
      '고성군': {'lat': 34.9732, 'lng': 128.3225},
      '남해군': {'lat': 34.8375, 'lng': 127.8924},
      '하동군': {'lat': 35.0674, 'lng': 127.7515},
      '산청군': {'lat': 35.4158, 'lng': 127.8736},
      '함양군': {'lat': 35.5203, 'lng': 127.7250},
      '거창군': {'lat': 35.6869, 'lng': 127.9095},
      '합천군': {'lat': 35.5665, 'lng': 128.1657},
    },
    '제주특별자치도': {
      '제주시': {'lat': 33.4996, 'lng': 126.5312},
      '서귀포시': {'lat': 33.2544, 'lng': 126.5600},
    },
  };

  // 하위 호환을 위한 평면 도시 목록 (기존 API와 호환)
  static Map<String, Map<String, double>> get majorCities {
    final Map<String, Map<String, double>> flatCities = {};
    
    for (final province in hierarchicalLocations.entries) {
      for (final city in province.value.entries) {
        flatCities[city.key] = city.value;
      }
    }
    
    return flatCities;
  }

  // 캐시된 위치 즉시 반환 (있는 경우)
  static LocationData? getCachedLocation() {
    return _currentLocation;
  }
  
  // 현재 위치 가져오기 (빠른 모드 지원)
  static Future<LocationData?> getCurrentLocation({bool useCachedFirst = true}) async {
    // 캐시된 위치가 있고 useCachedFirst가 true면 즉시 반환
    if (useCachedFirst && _currentLocation != null) {
      if (kDebugMode) {
        print('📍 캐시된 위치 반환: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
      }
      return _currentLocation;
    }
    
    // 새로운 위치 가져오기
    try {
      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          if (kDebugMode) {
            print('📍 위치 서비스가 비활성화됨');
          }
          return null;
        }
      }

      // 위치 권한 확인
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (kDebugMode) {
            print('📍 위치 권한이 거부됨');
          }
          return null;
        }
      }

      // 현재 위치 가져오기
      _currentLocation = await _location.getLocation();
      
      if (kDebugMode) {
        print('📍 현재 위치: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
      }
      
      return _currentLocation;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 위치 가져오기 실패: $e');
      }
      return null;
    }
  }

  // 선택된 도시 좌표 가져오기
  static Map<String, double>? getCityCoordinates(String cityName) {
    if (majorCities.containsKey(cityName)) {
      final coords = majorCities[cityName]!;
      if (kDebugMode) {
        print('🏙️ $cityName 좌표: ${coords['lat']}, ${coords['lng']}');
      }
      return coords;
    }
    return null;
  }

  // 현재 위치 또는 기본 위치 반환
  static Future<Map<String, double>> getLocationForSearch({String? selectedCity}) async {
    
    // 1. 선택된 도시가 있으면 해당 도시 좌표 사용
    if (selectedCity != null && selectedCity.isNotEmpty && selectedCity != '현재 위치') {
      final cityCoords = getCityCoordinates(selectedCity);
      if (cityCoords != null) {
        return cityCoords;
      }
    }
    
    // 2. 현재 위치 시도 (한국 내인지 확인)
    try {
      final currentLocation = await getCurrentLocation();
      if (currentLocation != null) {
        final lat = currentLocation.latitude!;
        final lng = currentLocation.longitude!;
        
        // 한국 영토 내인지 확인 (대략적인 경계)
        if (lat >= 33.0 && lat <= 43.0 && lng >= 124.0 && lng <= 132.0) {
          return {
            'lat': lat,
            'lng': lng,
          };
        } else {
          if (kDebugMode) {
            print('📍 에뮬레이터 해외 위치 감지 ($lat, $lng), 서울시로 기본값 설정');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GPS 위치 실패, 서울시청 기본값 사용: $e');
      }
    }
    
    // 3. 기본값: 서울시청
    return majorCities['서울시']!;
  }

  // 캐시된 현재 위치 반환 (빠른 접근용)
  static LocationData? get cachedLocation => _currentLocation;
  
  // 현재 위치가 있는지 확인
  static bool get hasCurrentLocation => _currentLocation != null;
  
  // 현재 위치에서 가장 가까운 도시 찾기 (정확한 도/시 매칭)
  static String? findNearestCity(double currentLat, double currentLng) {
    double minDistance = double.infinity;
    String? nearestCity;
    String? nearestProvince;
    
    for (final provinceEntry in hierarchicalLocations.entries) {
      final provinceName = provinceEntry.key;
      final cities = provinceEntry.value;
      
      for (final cityEntry in cities.entries) {
        final cityName = cityEntry.key;
        final cityCoords = cityEntry.value;
        final cityLat = cityCoords['lat']!;
        final cityLng = cityCoords['lng']!;
        final distance = calculateDistance(currentLat, currentLng, cityLat, cityLng);
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestCity = cityName;
          nearestProvince = provinceName;
        }
      }
    }
    
    if (kDebugMode) {
      print('🏙️ 가장 가까운 도시: $nearestCity ($nearestProvince) (거리: ${minDistance.toStringAsFixed(1)}km)');
    }
    
    return nearestCity;
  }
  
  // 도시명으로 도/특별시 찾기
  static String? findProvinceByCity(String cityName) {
    for (final provinceEntry in hierarchicalLocations.entries) {
      final provinceName = provinceEntry.key;
      final cities = provinceEntry.value;
      
      if (cities.containsKey(cityName)) {
        return provinceName;
      }
    }
    return null;
  }
  
  // 도/특별시 목록 가져오기
  static List<String> get provinces {
    return hierarchicalLocations.keys.toList();
  }
  
  // 특정 도/특별시의 시/군 목록 가져오기
  static List<String> getCitiesByProvince(String provinceName) {
    return hierarchicalLocations[provinceName]?.keys.toList() ?? [];
  }

  // 거리 계산 (Haversine formula)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = (dLat / 2) * (dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
        (dLon / 2) * (dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
  
  // 거리를 사용자 친화적인 형태로 포맷팅
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '${meters}m';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }
}