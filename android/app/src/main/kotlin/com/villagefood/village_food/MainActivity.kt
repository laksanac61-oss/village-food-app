package com.villagefood.village_food

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // high importance so new-order notifications pop up with sound (used by the notify-shop function)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("orders", "ออเดอร์ใหม่", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "แจ้งเมื่อมีออเดอร์ใหม่หรือลูกค้าส่งสลิป"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
