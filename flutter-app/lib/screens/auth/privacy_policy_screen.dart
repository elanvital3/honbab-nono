import 'package:flutter/material.dart';
import '../../constants/privacy_policy_content.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final Function(Map<String, bool>)? onConsentChanged;
  final bool showConsentOptions;
  
  const PrivacyPolicyScreen({
    super.key,
    this.onConsentChanged,
    this.showConsentOptions = false,
  });

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  // 동의 상태 관리
  bool _essentialConsent = false;
  bool _marketingConsent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
          '개인정보 처리방침',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더 정보
            _buildHeader(),
            
            // 처리방침 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildContent(),
              ),
            ),
            
            // 하단 버튼 또는 동의 섹션
            widget.showConsentOptions 
                ? _buildConsentSection(context)
                : _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2B48C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '현재 버전',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'v${PrivacyPolicyContent.version}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '최종 수정일: 2025년 1월 15일',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD2B48C), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '개인정보보호법에 따라 작성된 공식 처리방침입니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // 처리방침 텍스트를 섹션별로 분리
    final sections = _parseContentSections(PrivacyPolicyContent.fullContent);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목
        const Text(
          PrivacyPolicyContent.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 24),
        
        // 섹션들
        ...sections.map((section) => _buildSection(section)),
        
        const SizedBox(height: 32),
        
        // 연락처 강조
        _buildContactSection(),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSection(Map<String, String> section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section['title']!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Text(
                section['title']!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Text(
              section['content']!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2B48C), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contact_support,
                color: Color(0xFFD2B48C),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '개인정보 관련 문의',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildContactItem(
            icon: Icons.person,
            label: '개인정보보호책임자',
            value: '김태훈',
          ),
          const SizedBox(height: 8),
          
          _buildContactItem(
            icon: Icons.email,
            label: '이메일',
            value: 'elanvital3@gmail.com',
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '개인정보 처리와 관련한 모든 문의사항은 위 연락처로 문의해주시기 바랍니다. 신속하고 성실하게 답변해드리겠습니다.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2E7D32),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF666666),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE0E0E0), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 제목
          const Row(
            children: [
              Icon(
                Icons.fact_check,
                color: Color(0xFFD2B48C),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                '개인정보 처리 동의',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 필수 동의
          _buildConsentItem(
            title: '필수 동의 항목',
            description: '서비스 이용 및 안전한 매칭을 위한 개인정보 처리 (닉네임, 성별, 연령대, 출생년도)',
            isRequired: true,
            value: _essentialConsent,
            onChanged: (value) {
              setState(() {
                _essentialConsent = value ?? false;
                _notifyConsentChanged();
              });
            },
          ),
          
          const SizedBox(height: 10),
          
          // 선택 동의 - 마케팅
          _buildConsentItem(
            title: '선택 동의 - 마케팅 활용',
            description: '이벤트 알림 및 맞춤 서비스 제공',
            isRequired: false,
            value: _marketingConsent,
            onChanged: (value) {
              setState(() {
                _marketingConsent = value ?? false;
                _notifyConsentChanged();
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // 동의 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _essentialConsent ? _handleConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2B48C),
                disabledBackgroundColor: const Color(0xFFE0E0E0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _essentialConsent ? '동의하고 계속하기' : '필수 항목에 동의해주세요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _essentialConsent ? Colors.white : const Color(0xFF999999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentItem({
    required String title,
    required String description,
    required bool isRequired,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFFD2B48C) : const Color(0xFFE0E0E0),
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFD2B48C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRequired ? const Color(0xFFFFE5E5) : const Color(0xFFE5F3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isRequired ? '필수' : '선택',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isRequired ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _notifyConsentChanged() {
    if (widget.onConsentChanged != null) {
      widget.onConsentChanged!({
        'essential': _essentialConsent,
        'marketing': _marketingConsent,
      });
    }
  }

  void _handleConfirm() {
    Navigator.pop(context, {
      'essential': _essentialConsent,
      'marketing': _marketingConsent,
    });
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD2B48C),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            '확인',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _parseContentSections(String content) {
    final sections = <Map<String, String>>[];
    final lines = content.split('\n');
    
    String currentTitle = '';
    String currentContent = '';
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      // 섹션 구분선 체크
      if (line.contains('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')) {
        if (currentContent.isNotEmpty) {
          sections.add({
            'title': currentTitle,
            'content': currentContent.trim(),
          });
          currentTitle = '';
          currentContent = '';
        }
        continue;
      }
      
      // 이모지가 있는 제목 라인 체크
      if (line.trim().startsWith('🔍') || 
          line.trim().startsWith('📋') || 
          line.trim().startsWith('💾') || 
          line.trim().startsWith('🔒') || 
          line.trim().startsWith('🌍') || 
          line.trim().startsWith('⚖️') || 
          line.trim().startsWith('🛡️') || 
          line.trim().startsWith('👤') || 
          line.trim().startsWith('📞')) {
        
        if (currentContent.isNotEmpty) {
          sections.add({
            'title': currentTitle,
            'content': currentContent.trim(),
          });
        }
        
        currentTitle = line.trim();
        currentContent = '';
      } else {
        if (line.trim() != PrivacyPolicyContent.title) {
          currentContent += line + '\n';
        }
      }
    }
    
    // 마지막 섹션 추가
    if (currentContent.isNotEmpty) {
      sections.add({
        'title': currentTitle,
        'content': currentContent.trim(),
      });
    }
    
    return sections;
  }
}