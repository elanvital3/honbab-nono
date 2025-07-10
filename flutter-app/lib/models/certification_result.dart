class CertificationResult {
  final bool success;
  final String? name;
  final String? gender;
  final String? birthday;
  final String? phone;
  final String? carrier;
  final String? foreigner;
  final String? merchantUid;
  final String? impUid;
  final String? pgProvider;
  final String? errorMessage;
  final bool isAdult;

  CertificationResult({
    required this.success,
    this.name,
    this.gender,
    this.birthday,
    this.phone,
    this.carrier,
    this.foreigner,
    this.merchantUid,
    this.impUid,
    this.pgProvider,
    this.errorMessage,
    required this.isAdult,
  });

  factory CertificationResult.fromMap(Map<String, String> result) {
    final success = result['success'] == 'true';
    final birthday = result['birthday'];
    final isAdult = _calculateIsAdult(birthday);

    return CertificationResult(
      success: success,
      name: result['name'],
      gender: result['gender'],
      birthday: birthday,
      phone: result['phone'],
      carrier: result['carrier'],
      foreigner: result['foreigner'],
      merchantUid: result['merchant_uid'],
      impUid: result['imp_uid'],
      pgProvider: result['pg_provider'],
      errorMessage: result['error_msg'],
      isAdult: isAdult,
    );
  }

  // 성인 여부 계산 (만 19세 이상)
  static bool _calculateIsAdult(String? birthday) {
    if (birthday == null || birthday.isEmpty) return false;
    
    try {
      // birthday 형식: YYYYMMDD
      if (birthday.length != 8) return false;
      
      final year = int.parse(birthday.substring(0, 4));
      final month = int.parse(birthday.substring(4, 6));
      final day = int.parse(birthday.substring(6, 8));
      
      final birthDate = DateTime(year, month, day);
      final now = DateTime.now();
      final age = now.year - birthDate.year;
      
      // 생일이 지났는지 확인
      final hasBirthdayPassed = (now.month > birthDate.month) ||
          (now.month == birthDate.month && now.day >= birthDate.day);
      
      final actualAge = hasBirthdayPassed ? age : age - 1;
      
      return actualAge >= 19;
    } catch (e) {
      return false;
    }
  }

  // 성별을 앱에서 사용하는 형식으로 변환
  String? get normalizedGender {
    if (gender == null) return null;
    
    switch (gender!.toLowerCase()) {
      case 'male':
      case 'm':
      case '남':
      case '남성':
        return 'male';
      case 'female':
      case 'f':
      case '여':
      case '여성':
        return 'female';
      default:
        return null;
    }
  }

  // 출생연도 추출
  int? get birthYear {
    if (birthday == null || birthday!.length < 4) return null;
    
    try {
      return int.parse(birthday!.substring(0, 4));
    } catch (e) {
      return null;
    }
  }

  // 전화번호 포맷팅 (010-0000-0000)
  String? get formattedPhone {
    if (phone == null || phone!.length != 11) return phone;
    
    try {
      return '${phone!.substring(0, 3)}-${phone!.substring(3, 7)}-${phone!.substring(7, 11)}';
    } catch (e) {
      return phone;
    }
  }

  @override
  String toString() {
    return 'CertificationResult{'
        'success: $success, '
        'name: $name, '
        'gender: $gender, '
        'isAdult: $isAdult, '
        'errorMessage: $errorMessage'
        '}';
  }
}