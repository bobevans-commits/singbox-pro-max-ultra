package com.example.proxy_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * 普通代理服务 - 非 TUN 模式下的系统代理设置
 */
class ProxyService : android.app.Service() {
    companion object {
        const val NOTIFICATION_ID = 2
        const val CHANNEL_ID = "proxy_service_channel"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val configPath = intent?.getStringExtra("config_path") ?: return START_NOT_STICKY
        val kernelType = intent.getStringExtra("kernel_type") ?: "sing-box"

        // 启动前台服务
        startForeground(NOTIFICATION_ID, createNotification())

        // 在后台线程中启动代理
        Thread {
            try {
                startProxy(configPath, kernelType)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()

        return START_STICKY
    }

    private fun startProxy(configPath: String, kernelType: String) {
        // TODO: 实现实际的代理启动逻辑
        // 1. 加载对应内核的二进制文件
        // 2. 生成配置文件
        // 3. 启动进程
        // 4. 监听端口并设置系统代理
        
        println("Starting proxy service:")
        println("  Config: $configPath")
        println("  Kernel: $kernelType")
        
        // 模拟运行
        while (!Thread.interrupted()) {
            Thread.sleep(1000)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // 清理资源
    }

    override fun onBind(intent: Intent?): android.os.IBinder? {
        return null
    }

    private fun createNotification(): android.app.Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("代理服务运行中")
            .setContentText("点击打开应用")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Proxy Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Proxy service notification"
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
