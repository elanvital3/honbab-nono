import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
} from 'react-native';

const App = () => {
  const handleSocialLogin = (provider: string) => {
    console.log(`${provider} 로그인 시도`);
    alert(`${provider} 로그인 기능은 준비 중입니다!`);
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.emoji}>🍽️</Text>
          <Text style={styles.title}>혼밥노노</Text>
          <Text style={styles.subtitle}>
            혼자 가기 어려운 맛집을{'\n'}함께 경험해보세요
          </Text>
        </View>

        <View style={styles.buttonContainer}>
          <TouchableOpacity 
            style={[styles.button, styles.kakaoButton]}
            onPress={() => handleSocialLogin('카카오')}
          >
            <Text style={styles.buttonIcon}>💬</Text>
            <Text style={[styles.buttonText, styles.kakaoText]}>
              카카오로 시작하기
            </Text>
          </TouchableOpacity>

          <TouchableOpacity 
            style={[styles.button, styles.googleButton]}
            onPress={() => handleSocialLogin('구글')}
          >
            <Text style={styles.buttonIcon}>🌐</Text>
            <Text style={[styles.buttonText, styles.googleText]}>
              구글로 시작하기
            </Text>
          </TouchableOpacity>

          <TouchableOpacity 
            style={[styles.button, styles.naverButton]}
            onPress={() => handleSocialLogin('네이버')}
          >
            <Text style={[styles.buttonIcon, {fontSize: 16, fontWeight: 'bold'}]}>
              N
            </Text>
            <Text style={[styles.buttonText, styles.naverText]}>
              네이버로 시작하기
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>
            가입 시 이용약관 및 개인정보처리방침에 동의합니다
          </Text>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  content: {
    flex: 1,
    paddingHorizontal: 30,
    justifyContent: 'space-between',
  },
  header: {
    alignItems: 'center',
    marginTop: 100,
  },
  emoji: {
    fontSize: 80,
    marginBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 12,
  },
  subtitle: {
    fontSize: 16,
    color: '#666666',
    textAlign: 'center',
    lineHeight: 24,
  },
  buttonContainer: {
    gap: 12,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    paddingHorizontal: 20,
    borderRadius: 12,
    gap: 10,
  },
  buttonIcon: {
    fontSize: 20,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '600',
  },
  kakaoButton: {
    backgroundColor: '#FEE500',
  },
  kakaoText: {
    color: '#3C1E1E',
  },
  googleButton: {
    backgroundColor: '#4285F4',
  },
  googleText: {
    color: '#FFFFFF',
  },
  naverButton: {
    backgroundColor: '#03C75A',
  },
  naverText: {
    color: '#FFFFFF',
  },
  footer: {
    alignItems: 'center',
    marginBottom: 40,
  },
  footerText: {
    fontSize: 12,
    color: '#999999',
    textAlign: 'center',
  },
});

export default App;