import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
} from 'react-native';
import Icon from 'react-native-vector-icons/Ionicons';

const mockChats = [
  {
    id: '1',
    restaurant: '강남 삼겹살집',
    lastMessage: '모임 30분 전입니다!',
    time: '5분 전',
    unreadCount: 2,
    participants: 3,
  },
  {
    id: '2',
    restaurant: '홍대 파스타 맛집',
    lastMessage: '내일 점심 모임 확정!',
    time: '1시간 전',
    unreadCount: 0,
    participants: 2,
  },
];

const ChatListScreen = () => {
  const renderChatItem = ({item}: {item: any}) => (
    <TouchableOpacity style={styles.chatItem}>
      <View style={styles.chatIcon}>
        <Icon name="restaurant" size={24} color="#FF6B6B" />
      </View>
      
      <View style={styles.chatContent}>
        <View style={styles.chatHeader}>
          <Text style={styles.restaurantName}>{item.restaurant}</Text>
          <Text style={styles.chatTime}>{item.time}</Text>
        </View>
        
        <View style={styles.chatFooter}>
          <Text style={styles.lastMessage} numberOfLines={1}>
            {item.lastMessage}
          </Text>
          <View style={styles.chatInfo}>
            <Text style={styles.participantCount}>{item.participants}명</Text>
            {item.unreadCount > 0 && (
              <View style={styles.unreadBadge}>
                <Text style={styles.unreadCount}>{item.unreadCount}</Text>
              </View>
            )}
          </View>
        </View>
      </View>
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      <View style={styles.header}>
        <Text style={styles.headerTitle}>채팅</Text>
      </View>

      <FlatList
        data={mockChats}
        renderItem={renderChatItem}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
      />
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
  listContainer: {
    paddingVertical: 8,
  },
  chatItem: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingVertical: 16,
    alignItems: 'center',
  },
  chatIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#FFF5F5',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  chatContent: {
    flex: 1,
  },
  chatHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  restaurantName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333333',
  },
  chatTime: {
    fontSize: 12,
    color: '#999999',
  },
  chatFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  lastMessage: {
    flex: 1,
    fontSize: 14,
    color: '#666666',
    marginRight: 8,
  },
  chatInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  participantCount: {
    fontSize: 12,
    color: '#999999',
  },
  unreadBadge: {
    backgroundColor: '#FF6B6B',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
  },
  unreadCount: {
    fontSize: 12,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
});

export default ChatListScreen;