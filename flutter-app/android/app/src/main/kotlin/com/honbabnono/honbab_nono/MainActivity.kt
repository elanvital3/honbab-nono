package com.honbabnono.honbab_nono

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.view.View
import android.graphics.Color

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 화면이 검게 나오는 문제 방지를 위한 다양한 설정
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        
        // 투명도 문제 방지
        window.statusBarColor = Color.WHITE
        window.navigationBarColor = Color.WHITE
        
        // 시스템 UI 가시성 설정
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        
        // 백그라운드 색상 강제 설정
        window.setBackgroundDrawableResource(android.R.color.white)
        
        // 스플래시 화면을 3초간 유지
        Handler(Looper.getMainLooper()).postDelayed({
            // Flutter 엔진이 준비되면 스플래시 제거
        }, 3000)
    }
    
    override fun onResume() {
        super.onResume()
        // 앱이 포그라운드로 돌아올 때 화면 새로고침 강제
        window.decorView.invalidate()
        // 백그라운드 색상 재설정
        window.setBackgroundDrawableResource(android.R.color.white)
    }
    
    override fun onPause() {
        super.onPause()
        // 백그라운드로 갈 때 화면 상태 유지
    }
    
    override fun onStop() {
        super.onStop()
        // 앱이 완전히 숨겨질 때 상태 보존
    }
    
    override fun onRestart() {
        super.onRestart()
        // 앱이 다시 시작될 때 UI 강제 새로고침
        window.decorView.invalidate()
        window.setBackgroundDrawableResource(android.R.color.white)
    }
}
