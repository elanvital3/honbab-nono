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

// 임시 데이터
const mockMeetings = [
  {
    id: '1',
    restaurant: '강남 삼겹살집',
    time: '오늘 7:00 PM',
    participants: 2,
    maxParticipants: 4,
    distance: '500m',
    host: '김혜진',
    rating: 4.5,
  },
  {
    id: '2',
    restaurant: '홍대 파스타 맛집',
    time: '내일 12:30 PM',
    participants: 1,
    maxParticipants: 3,
    distance: '1.2km',
    host: '이민수',
    rating: 4.2,
  },
];

const HomeScreen = () => {
  const renderMeetingItem = ({item}: {item: any}) => (
    <TouchableOpacity style={styles.meetingCard}>
      <View style={styles.cardHeader}>
        <Text style={styles.restaurantName}>{item.restaurant}</Text>
        <Text style={styles.distance}>{item.distance}</Text>
      </View>
      
      <View style={styles.cardContent}>
        <View style={styles.timeContainer}>
          <Icon name="time-outline" size={16} color="#666666" />
          <Text style={styles.time}>{item.time}</Text>
        </View>
        
        <View style={styles.participantsContainer}>
          <Icon name="people-outline" size={16} color="#666666" />
          <Text style={styles.participants}>
            {item.participants}/{item.maxParticipants}명
          </Text>
        </View>
      </View>
      
      <View style={styles.cardFooter}>
        <View style={styles.hostInfo}>
          <Text style={styles.hostLabel}>방장</Text>
          <Text style={styles.hostName}>{item.host}</Text>
          <View style={styles.ratingContainer}>
            <Icon name="star" size={12} color="#FFD700" />
            <Text style={styles.rating}>{item.rating}</Text>
          </View>
        </View>
      </View>
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      <View style={styles.header}>
        <Text style={styles.headerTitle}>내 주변 맛집 모임</Text>
        <TouchableOpacity style={styles.locationButton}>
          <Icon name="location-outline" size={16} color="#FF6B6B" />
          <Text style={styles.locationText}>강남구</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.filterContainer}>
        <TouchableOpacity style={[styles.filterButton, styles.activeFilter]}>
          <Text style={[styles.filterText, styles.activeFilterText]}>전체</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.filterButton}>
          <Text style={styles.filterText}>오늘</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.filterButton}>
          <Text style={styles.filterText}>내일</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.filterButton}>
          <Text style={styles.filterText}>가까운 순</Text>
        </TouchableOpacity>
      </View>

      <FlatList
        data={mockMeetings}
        renderItem={renderMeetingItem}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
      />

      <TouchableOpacity style={styles.fab}>
        <Icon name="add" size={28} color="#FFFFFF" />
      </TouchableOpacity>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
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
  locationButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  locationText: {
    fontSize: 14,
    color: '#FF6B6B',
    fontWeight: '500',
  },
  filterContainer: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingVertical: 12,
    gap: 8,
  },
  filterButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#F5F5F5',
  },
  activeFilter: {
    backgroundColor: '#FF6B6B',
  },
  filterText: {
    fontSize: 14,
    color: '#666666',
    fontWeight: '500',
  },
  activeFilterText: {
    color: '#FFFFFF',
  },
  listContainer: {
    padding: 20,
    paddingBottom: 100,
  },
  meetingCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
    borderWidth: 1,
    borderColor: '#F0F0F0',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  restaurantName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333333',
  },
  distance: {
    fontSize: 12,
    color: '#999999',
  },
  cardContent: {
    gap: 6,
    marginBottom: 12,
  },
  timeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  time: {
    fontSize: 14,
    color: '#666666',
  },
  participantsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  participants: {
    fontSize: 14,
    color: '#666666',
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  hostInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  hostLabel: {
    fontSize: 12,
    color: '#999999',
  },
  hostName: {
    fontSize: 12,
    color: '#333333',
    fontWeight: '500',
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  rating: {
    fontSize: 12,
    color: '#666666',
  },
  fab: {
    position: 'absolute',
    right: 20,
    bottom: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#FF6B6B',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
});

export default HomeScreen;