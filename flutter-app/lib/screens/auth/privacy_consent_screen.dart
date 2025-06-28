import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import 'signup_complete_screen.dart';
import '../home/home_screen.dart';

class PrivacyConsentScreen extends StatefulWidget {
  final String userId;
  final String? defaultName;
  final String? profileImageUrl;
  final String? email;
  final String? kakaoId;
  final bool isUpdate; // 기존 사용자의 동의 업데이트인지 여부

  const PrivacyConsentScreen({
    super.key,
    required this.userId,
    this.defaultName,
    this.profileImageUrl,
    this.email,
    this.kakaoId,
    this.isUpdate = false,
  });

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _isNicknameValid = false;
  String? _nicknameError;

  @override
  void initState() {
    super.initState();
    if (widget.isUpdate) {
      _loadExistingConsents();
    }
  }

  Future<void> _loadExistingConsents() async {
    final existingConsents = await PrivacyConsentService.getUserConsent(widget.userId);
    if (existingConsents != null && mounted) {
      setState(() {
        _consentData = existingConsents;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isUpdate ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF333333),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '개인정보 동의 설정',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ) : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.isUpdate) ...[
              // 신규 가입용 헤더
              _buildNewUserHeader(),
              const SizedBox(height: 20),
            ],
            
            // 동의 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isUpdate) ...[
                      const SizedBox(height: 20),
                      _buildUpdateHeader(),
                      const SizedBox(height: 30),
                    ],
                    
                    _buildConsentButton(),
                    const SizedBox(height: 20),
                    
                    if (_consentData.isNotEmpty) ...[
                      _buildConsentStatus(),
                      const SizedBox(height: 30),
                    ],
                    
                    _buildInfoSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            
            // 하단 버튼
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewUserHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        children: [
          // 프로필 사진
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: widget.profileImageUrl != null
                  ? Image.network(
                      widget.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            '환영합니다! 🎉',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '혼밥노노 서비스 이용을 위해\n개인정보 처리방침에 동의해주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '개인정보 동의 설정',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '언제든지 동의 내용을 변경하실 수 있습니다.',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security,
                color: Color(0xFFD2B48C),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '개인정보 처리방침 동의',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          const Text(
            '안전하고 개인화된 서비스 제공을 위해 개인정보 수집 및 이용에 대한 동의가 필요합니다.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showConsentDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2B48C),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '동의 항목 확인하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 동의 상태',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildConsentStatusItem(
            '필수 동의',
            _consentData['essential'] ?? false,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          
          _buildConsentStatusItem(
            '선택 동의 - 프로필 정보',
            _consentData['optional_profile'] ?? false,
          ),
          const SizedBox(height: 12),
          
          _buildConsentStatusItem(
            '선택 동의 - 마케팅 활용',
            _consentData['marketing'] ?? false,
          ),
        ],
      ),
    );
  }

  Widget _buildConsentStatusItem(String title, bool isConsented, {bool isRequired = false}) {
    return Row(
      children: [
        Icon(
          isConsented ? Icons.check_circle : Icons.cancel,
          color: isConsented ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
            ),
          ),
        ),
        if (isRequired) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '필수',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD32F2F),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2B48C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '안내사항',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          const Text(
            '• 필수 동의 항목은 서비스 이용을 위해 반드시 필요합니다.\n'
            '• 선택 동의 항목은 거부하셔도 기본 서비스 이용이 가능합니다.\n'
            '• 동의 내용은 마이페이지에서 언제든지 변경하실 수 있습니다.\n'
            '• 개인정보는 안전하게 암호화되어 보관됩니다.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF2E7D32),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        children: [
          if (widget.isUpdate) ...[
            // 업데이트 모드 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_consentData['essential'] ?? false) ? _handleSaveUpdate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2B48C),
                  disabledBackgroundColor: const Color(0xFFE0E0E0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        (_consentData['essential'] ?? false) ? '설정 저장' : '필수 항목에 동의해주세요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (_consentData['essential'] ?? false) ? Colors.white : const Color(0xFF999999),
                        ),
                      ),
              ),
            ),
          ] else ...[
            // 신규 가입 모드 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_consentData['essential'] ?? false) ? _handleContinueSignup : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2B48C),
                  disabledBackgroundColor: const Color(0xFFE0E0E0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        (_consentData['essential'] ?? false) ? '동의하고 계속' : '필수 항목에 동의해주세요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (_consentData['essential'] ?? false) ? Colors.white : const Color(0xFF999999),
                        ),
                      ),
              ),
            ),
          ],
          
          if (!widget.isUpdate) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '나중에 하기',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5F5F5),
      ),
      child: const Icon(
        Icons.person,
        size: 40,
        color: Color(0xFFBBBBBB),
      ),
    );
  }

  void _showConsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrivacyConsentDialog(
        onConsentChanged: (consents) {
          setState(() {
            _consentData = consents;
          });
        },
        onClose: () => Navigator.pop(context),
      ),
    ).then((result) {
      if (result != null && result is Map<String, bool>) {
        setState(() {
          _consentData = result;
        });
      }
    });
  }

  Future<void> _handleContinueSignup() async {
    if (!(_consentData['essential'] ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 동의 상태 저장
      final success = await PrivacyConsentService.saveConsent(
        userId: widget.userId,
        consentData: _consentData,
      );

      if (success && mounted) {
        // 닉네임 입력 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SignupCompleteScreen(
              userId: widget.userId,
              defaultName: widget.defaultName,
              profileImageUrl: widget.profileImageUrl,
              email: widget.email,
              kakaoId: widget.kakaoId,
            ),
          ),
        );
      } else {
        throw Exception('동의 상태 저장에 실패했습니다.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSaveUpdate() async {
    if (!(_consentData['essential'] ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 동의 상태 업데이트
      final success = await PrivacyConsentService.saveConsent(
        userId: widget.userId,
        consentData: _consentData,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('동의 설정이 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('동의 상태 저장에 실패했습니다.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}