import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../components/common/common_card.dart';
import '../../components/common/common_button.dart';

class UnifiedNotificationTestScreen extends StatefulWidget {
  const UnifiedNotificationTestScreen({super.key});

  @override
  State<UnifiedNotificationTestScreen> createState() => _UnifiedNotificationTestScreenState();
}

class _UnifiedNotificationTestScreenState extends State<UnifiedNotificationTestScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _targetTokenController = TextEditingController();
  final TextEditingController _testTitleController = TextEditingController();
  final TextEditingController _testBodyController = TextEditingController();
  
  String? _fcmToken;
  String? _userId;
  bool _isLoading = false;
  String _testResult = '';
  String _status = '알림 서비스 초기화 중...';

  @override
  void initState() {
    super.initState();
    _initializeAndLoadInfo();
    // 기본값 설정
    _testTitleController.text = '🧪 크로스 디바이스 테스트';
    _testBodyController.text = '이것은 크로스 디바이스 FCM 테스트입니다.';
  }
  
  @override
  void dispose() {
    _targetTokenController.dispose();
    _testTitleController.dispose();
    _testBodyController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoadInfo() async {
    setState(() {
      _isLoading = true;
      _status = 'FCM 초기화 중...';
    });

    try {
      // FCM 초기화
      await _notificationService.initialize();
      final token = _notificationService.fcmToken;
      
      // 사용자 정보 로드
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userId = user.uid;
        _fcmToken = token;
        
        // 사용자 문서 확인
        final userDoc = await UserService.getUser(user.uid);
        
        setState(() {
          _status = _notificationService.isInitialized ? 'FCM 초기화 완료' : 'FCM 초기화 실패';
          _testResult = '''
✅ 통합 알림 시스템 상태 확인

📱 기본 정보:
   • 사용자 ID: ${user.uid}
   • 사용자 이름: ${userDoc?.name ?? '없음'}
   • 이메일: ${user.email ?? '없음'}

🔑 FCM 토큰 정보:
   • 토큰 상태: ${token != null ? '정상' : '없음'}
   • 토큰: ${token?.substring(0, 30) ?? '없음'}...
   • Firestore 저장: ${userDoc?.fcmToken != null ? '완료' : '필요'}

🔔 알림 시스템 상태:
   • 초기화: ${_notificationService.isInitialized ? '완료' : '실패'}
   • 권한: 확인 필요
          ''';
        });
      }

      if (kDebugMode) {
        print('✅ 통합 알림 테스트 화면 초기화 완료');
        print('🔑 FCM 토큰: ${token?.substring(0, 50)}...');
      }
    } catch (e) {
      setState(() {
        _status = '초기화 실패: $e';
        _testResult = '❌ 초기화 실패: $e';
      });
      if (kDebugMode) {
        print('❌ 통합 알림 테스트 화면 초기화 실패: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFCMToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult += '\n\n❌ 로그인된 사용자가 없습니다';
        });
        return;
      }

      await _notificationService.saveFCMTokenToFirestore(user.uid);
      setState(() {
        _testResult += '\n\n✅ FCM 토큰 저장 완료';
      });
      
      if (kDebugMode) {
        print('✅ FCM 토큰 수동 저장 완료');
      }
    } catch (e) {
      setState(() {
        _testResult += '\n\n❌ FCM 토큰 저장 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLocalNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService().showTestNotification(
        '🧪 로컬 알림 테스트',
        '로컬 알림이 정상적으로 작동합니다!',
      );
      
      setState(() {
        _testResult += '\n\n✅ 로컬 알림 테스트 성공';
      });
    } catch (e) {
      setState(() {
        _testResult += '\n\n❌ 로컬 알림 테스트 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testBasicFCMNotification() async {
    if (_fcmToken == null) {
      setState(() {
        _testResult += '\n\n❌ FCM 토큰이 없어서 테스트 불가';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService().sendRealFCMMessage(
        targetToken: _fcmToken!,
        title: '🧪 기본 FCM 알림 테스트',
        body: 'Firebase Cloud Messaging이 정상적으로 작동합니다!',
        type: 'test',
        channelId: 'test',
      );
      
      setState(() {
        _testResult += '\n\n✅ 기본 FCM 알림 테스트 성공';
      });
    } catch (e) {
      setState(() {
        _testResult += '\n\n❌ 기본 FCM 알림 테스트 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRealMeetingNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService().testRealMeetingNotification();
      
      setState(() {
        _testResult += '\n\n✅ 실제 모임 알림 테스트 성공';
      });
    } catch (e) {
      setState(() {
        _testResult += '\n\n❌ 실제 모임 알림 테스트 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testCrossDeviceNotification() async {
    final targetToken = _targetTokenController.text.trim();
    if (targetToken.isEmpty) {
      setState(() {
        _testResult += '\n\n❌ 대상 FCM 토큰을 입력해주세요';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService().sendRealFCMMessage(
        targetToken: targetToken,
        title: _testTitleController.text,
        body: _testBodyController.text,
        type: 'cross_device_test',
        channelId: 'test',
      );
      
      setState(() {
        _testResult += '\n\n✅ 크로스 디바이스 알림 테스트 성공';
      });
    } catch (e) {
      setState(() {
        _testResult += '\n\n❌ 크로스 디바이스 알림 테스트 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupAllData() async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 경고'),
        content: const Text(
          '모든 사용자 데이터와 FCM 토큰을 삭제합니다.\n'
          '이 작업은 되돌릴 수 없습니다.\n\n'
          '정말로 진행하시겠습니까?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _testResult += '\n\n🧹 전체 데이터 정리 시작...';
    });

    try {
      // 1. Firestore 컬렉션들 정리
      await _cleanupFirestoreCollections();
      
      // 2. Firebase Auth 사용자들 정리
      await _cleanupAuthUsers();
      
      // 3. 현재 사용자 로그아웃
      await FirebaseAuth.instance.signOut();
      
      setState(() {
        _testResult += '\n\n🎉 전체 데이터 정리 완료!';
        _testResult += '\n- Firestore 컬렉션들 삭제됨';
        _testResult += '\n- Firebase Auth 사용자들 삭제됨';
        _testResult += '\n- 현재 사용자 로그아웃됨';
        _testResult += '\n\n이제 새로 가입해서 테스트하세요.';
      });
      
      // 잠시 후 로그인 화면으로 이동
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      });
      
    } catch (e) {
      setState(() {
        _testResult += '\n\n❌ 데이터 정리 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupFirestoreCollections() async {
    final collections = ['users', 'meetings', 'messages', 'fcm_tokens', 'user_ratings', 'notifications'];
    final firestore = FirebaseFirestore.instance;
    
    for (final collectionName in collections) {
      try {
        final snapshot = await firestore.collection(collectionName).get();
        final batch = firestore.batch();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        
        setState(() {
          _testResult += '\n  ✅ $collectionName: ${snapshot.docs.length}개 문서 삭제';
        });
      } catch (e) {
        setState(() {
          _testResult += '\n  ❌ $collectionName 삭제 실패: $e';
        });
      }
    }
  }

  Future<void> _cleanupAuthUsers() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('deleteAllAuthUsers');
      final result = await callable.call();
      
      if (result.data['success'] == true) {
        final deletedCount = result.data['deletedCount'] ?? 0;
        setState(() {
          _testResult += '\n  ✅ Firebase Auth: ${deletedCount}명 사용자 삭제';
        });
      } else {
        setState(() {
          _testResult += '\n  ❌ Firebase Auth 사용자 삭제 실패';
        });
      }
    } catch (e) {
      setState(() {
        _testResult += '\n  ❌ Firebase Auth 삭제 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.onSurface,
        elevation: 0,
        title: Text('통합 알림 테스트', style: AppTextStyles.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 표시 섹션
            CommonCard(
              padding: AppPadding.all20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 시스템 상태',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _status.contains('완료') ? Colors.green : 
                             _status.contains('실패') ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CommonButton(
                    text: '🔄 상태 새로고침',
                    variant: ButtonVariant.outline,
                    onPressed: _isLoading ? null : _initializeAndLoadInfo,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 토큰 관리 섹션
            CommonCard(
              padding: AppPadding.all20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔧 토큰 관리',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  CommonButton(
                    text: '💾 FCM 토큰 저장',
                    variant: ButtonVariant.primary,
                    onPressed: _isLoading ? null : _saveFCMToken,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  CommonButton(
                    text: '🧹 전체 데이터 정리',
                    variant: ButtonVariant.outline,
                    onPressed: _isLoading ? null : _cleanupAllData,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 기본 알림 테스트 섹션
            CommonCard(
              padding: AppPadding.all20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧪 기본 알림 테스트',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  CommonButton(
                    text: '📱 로컬 알림 테스트',
                    variant: ButtonVariant.secondary,
                    onPressed: _isLoading ? null : _testLocalNotification,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  CommonButton(
                    text: '☁️ 기본 FCM 테스트',
                    variant: ButtonVariant.secondary,
                    onPressed: _isLoading ? null : _testBasicFCMNotification,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  CommonButton(
                    text: '🧪 실제 모임 알림 테스트',
                    variant: ButtonVariant.outline,
                    onPressed: _isLoading ? null : _testRealMeetingNotification,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 크로스 디바이스 테스트 섹션
            CommonCard(
              padding: AppPadding.all20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔄 크로스 디바이스 테스트',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _targetTokenController,
                    decoration: const InputDecoration(
                      labelText: '대상 FCM 토큰',
                      hintText: '다른 디바이스의 FCM 토큰을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _testTitleController,
                    decoration: const InputDecoration(
                      labelText: '알림 제목',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _testBodyController,
                    decoration: const InputDecoration(
                      labelText: '알림 내용',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CommonButton(
                    text: '🚀 크로스 디바이스 알림 발송',
                    variant: ButtonVariant.primary,
                    onPressed: _isLoading ? null : _testCrossDeviceNotification,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 테스트 결과 표시 섹션
            CommonCard(
              padding: AppPadding.all20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 테스트 결과',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surfaceContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppDesignTokens.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _testResult.isEmpty ? '테스트 결과가 여기에 표시됩니다...' : _testResult,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}