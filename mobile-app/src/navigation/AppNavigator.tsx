import React from 'react';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {createStackNavigator} from '@react-navigation/stack';
import Icon from 'react-native-vector-icons/Ionicons';

import HomeScreen from '../screens/meeting/HomeScreen';
import MapScreen from '../screens/map/MapScreen';
import ChatListScreen from '../screens/chat/ChatListScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';
import LoginScreen from '../screens/auth/LoginScreen';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

const MainTabNavigator = () => {
  return (
    <Tab.Navigator
      screenOptions={({route}) => ({
        tabBarIcon: ({focused, color, size}) => {
          let iconName = '';

          switch (route.name) {
            case '모임':
              iconName = focused ? 'restaurant' : 'restaurant-outline';
              break;
            case '지도':
              iconName = focused ? 'map' : 'map-outline';
              break;
            case '채팅':
              iconName = focused ? 'chatbubbles' : 'chatbubbles-outline';
              break;
            case '마이':
              iconName = focused ? 'person' : 'person-outline';
              break;
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#FF6B6B',
        tabBarInactiveTintColor: 'gray',
        tabBarStyle: {
          paddingBottom: 5,
          height: 60,
        },
      })}>
      <Tab.Screen 
        name="모임" 
        component={HomeScreen}
        options={{headerShown: false}}
      />
      <Tab.Screen 
        name="지도" 
        component={MapScreen}
        options={{headerShown: false}}
      />
      <Tab.Screen 
        name="채팅" 
        component={ChatListScreen}
        options={{headerShown: false}}
      />
      <Tab.Screen 
        name="마이" 
        component={ProfileScreen}
        options={{headerShown: false}}
      />
    </Tab.Navigator>
  );
};

const AppNavigator = () => {
  const isLoggedIn = false; // TODO: 실제 로그인 상태 관리

  return (
    <Stack.Navigator screenOptions={{headerShown: false}}>
      {isLoggedIn ? (
        <Stack.Screen name="MainTabs" component={MainTabNavigator} />
      ) : (
        <Stack.Screen name="Login" component={LoginScreen} />
      )}
    </Stack.Navigator>
  );
};

export default AppNavigator;