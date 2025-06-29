import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/location_service.dart';
import '../auth/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _textSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    // 아이콘 애니메이션
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _iconScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    ));
    
    _iconOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // 텍스트 애니메이션
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));
    
    _textSlideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    // 로딩 애니메이션
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  void _startSplashSequence() async {
    // 상태바 스타일 설정
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    // 애니메이션 시퀀스
    await Future.delayed(const Duration(milliseconds: 200));
    _iconController.forward();
    
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    _loadingController.repeat();
    
    // 위치 초기화와 최소 스플래시 시간을 동시에 실행
    await Future.wait([
      _initializeLocation(),
      Future.delayed(const Duration(milliseconds: 1800)), // 최소 2.5초 보장
    ]);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  Future<void> _initializeLocation() async {
    try {
      // 3초 타임아웃 설정
      final locationFuture = LocationService.getCurrentLocation();
      final location = await locationFuture.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      
      if (location != null && mounted) {
        // GPS 위치에서 가장 가까운 도시 찾기
        final nearestCity = LocationService.findNearestCity(
          location.latitude!,
          location.longitude!
        );
        
        if (nearestCity != null) {
          // SharedPreferences에 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastKnownCity', nearestCity);
          print('📍 스플래시에서 위치 초기화 성공: $nearestCity');
        }
      }
    } catch (e) {
      // 에러 발생해도 앱은 계속 진행
      print('📍 스플래시 위치 초기화 실패: $e');
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 여백
            const Spacer(flex: 2),
            
            // 중앙 아이콘 + 텍스트 영역
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 아이콘
                  AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: Opacity(
                          opacity: _iconOpacityAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 앱 이름
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlideAnimation.value),
                        child: Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: const Text(
                            '혼밥노노',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 서브 텍스트
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlideAnimation.value),
                        child: Opacity(
                          opacity: _textOpacityAnimation.value * 0.7,
                          child: const Text(
                            '혼여는 좋지만 맛집은 함께 🥹',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // 하단 로딩 인디케이터
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, child) {
                      return _buildLoadingDots();
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        // 각 점의 애니메이션 지연 시간
        final delay = index * 0.2;
        final animationValue = _loadingController.value;
        
        // 0.0 ~ 1.0 사이에서 반복되는 opacity 계산
        double opacity = 0.3;
        final cycleTime = (animationValue + delay) % 1.0;
        
        if (cycleTime < 0.5) {
          opacity = 0.3 + (cycleTime * 1.4); // 0.3 → 1.0
        } else {
          opacity = 1.0 - ((cycleTime - 0.5) * 1.4); // 1.0 → 0.3
        }
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFD2B48C).withOpacity(opacity.clamp(0.3, 1.0)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}