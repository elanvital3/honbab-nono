import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  ScrollView,
} from 'react-native';
import Icon from 'react-native-vector-icons/Ionicons';

const ProfileScreen = () => {
  const menuItems = [
    {
      id: '1',
      title: '내 모임 내역',
      icon: 'list-outline',
      onPress: () => console.log('내 모임 내역'),
    },
    {
      id: '2',
      title: '평가 관리',
      icon: 'star-outline',
      onPress: () => console.log('평가 관리'),
    },
    {
      id: '3',
      title: '설정',
      icon: 'settings-outline',
      onPress: () => console.log('설정'),
    },
    {
      id: '4',
      title: '고객센터',
      icon: 'help-circle-outline',
      onPress: () => console.log('고객센터'),
    },
  ];

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      <ScrollView showsVerticalScrollIndicator={false}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>마이페이지</Text>
        </View>

        <View style={styles.profileSection}>
          <View style={styles.profileImage}>
            <Icon name="person" size={40} color="#666666" />
          </View>
          
          <View style={styles.profileInfo}>
            <Text style={styles.profileName}>김혜진</Text>
            <Text style={styles.profileAge}>28세 • 여성</Text>
            
            <View style={styles.ratingContainer}>
              <View style={styles.ratingItem}>
                <Icon name="time" size={16} color="#666666" />
                <Text style={styles.ratingLabel}>시간 준수</Text>
                <Text style={styles.ratingValue}>4.5</Text>
              </View>
              
              <View style={styles.ratingItem}>
                <Icon name="chatbubble" size={16} color="#666666" />
                <Text style={styles.ratingLabel}>대화 매너</Text>
                <Text style={styles.ratingValue}>4.2</Text>
              </View>
              
              <View style={styles.ratingItem}>
                <Icon name="heart" size={16} color="#666666" />
                <Text style={styles.ratingLabel}>재만남 의향</Text>
                <Text style={styles.ratingValue}>4.0</Text>
              </View>
            </View>
            
            <View style={styles.badgeContainer}>
              <View style={styles.badge}>
                <Text style={styles.badgeText}>🆕 신규</Text>
              </View>
              <View style={styles.badge}>
                <Text style={styles.badgeText}>🏢 직장인</Text>
              </View>
            </View>
          </View>
        </View>

        <View style={styles.statsSection}>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>5</Text>
            <Text style={styles.statLabel}>참여한 모임</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>2</Text>
            <Text style={styles.statLabel}>주최한 모임</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>4.2</Text>
            <Text style={styles.statLabel}>평균 평점</Text>
          </View>
        </View>

        <View style={styles.menuSection}>
          {menuItems.map((item) => (
            <TouchableOpacity
              key={item.id}
              style={styles.menuItem}
              onPress={item.onPress}
            >
              <View style={styles.menuLeft}>
                <Icon name={item.icon} size={24} color="#666666" />
                <Text style={styles.menuTitle}>{item.title}</Text>
              </View>
              <Icon name="chevron-forward" size={20} color="#CCCCCC" />
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity style={styles.logoutButton}>
          <Text style={styles.logoutText}>로그아웃</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  header: {
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333333',
  },
  profileSection: {
    flexDirection: 'row',
    padding: 20,
    alignItems: 'center',
  },
  profileImage: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#F5F5F5',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  profileInfo: {
    flex: 1,
  },
  profileName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 4,
  },
  profileAge: {
    fontSize: 14,
    color: '#666666',
    marginBottom: 12,
  },
  ratingContainer: {
    gap: 6,
    marginBottom: 12,
  },
  ratingItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  ratingLabel: {
    fontSize: 12,
    color: '#666666',
    flex: 1,
  },
  ratingValue: {
    fontSize: 12,
    color: '#FF6B6B',
    fontWeight: 'bold',
  },
  badgeContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  badge: {
    backgroundColor: '#FFF5F5',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  badgeText: {
    fontSize: 12,
    color: '#FF6B6B',
  },
  statsSection: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingVertical: 16,
    backgroundColor: '#F9F9F9',
    marginHorizontal: 20,
    borderRadius: 12,
    marginBottom: 20,
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    color: '#666666',
  },
  statDivider: {
    width: 1,
    backgroundColor: '#E0E0E0',
    marginHorizontal: 16,
  },
  menuSection: {
    paddingHorizontal: 20,
  },
  menuItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  menuLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  menuTitle: {
    fontSize: 16,
    color: '#333333',
  },
  logoutButton: {
    margin: 20,
    paddingVertical: 16,
    alignItems: 'center',
    borderRadius: 12,
    backgroundColor: '#F5F5F5',
  },
  logoutText: {
    fontSize: 16,
    color: '#666666',
  },
});

export default ProfileScreen;