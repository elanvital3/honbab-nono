import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/user_service.dart';
import '../../models/user.dart' as app_user;
import 'login_screen.dart';
import '../home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<firebase_auth.User?>(context);
    
    // Firebase 사용자가 없으면 로그인 화면
    if (firebaseUser == null) {
      return const LoginScreen();
    }
    
    // Firebase 사용자는 있지만 Firestore 데이터 확인 필요
    return FutureBuilder<app_user.User?>(
      future: UserService.getUser(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 중 - 미니멀한 로딩 화면
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD2B48C),
                strokeWidth: 2,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          // 에러 발생 시 로그인 화면으로
          return const LoginScreen();
        }
        
        final firestoreUser = snapshot.data;
        
        if (firestoreUser != null && firestoreUser.name.isNotEmpty && firestoreUser.name != 'NEW_USER') {
          // 완전한 사용자 데이터가 있으면 홈 화면
          return const HomeScreen();
        } else {
          // Firestore에 데이터가 없거나 불완전하면 로그인 화면
          return const LoginScreen();
        }
      },
    );
  }
}