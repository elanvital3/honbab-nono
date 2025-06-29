package com.honbabnono.honbab_nono

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 스플래시 화면을 3초간 유지
        Handler(Looper.getMainLooper()).postDelayed({
            // Flutter 엔진이 준비되면 스플래시 제거
        }, 3000)
    }
}
