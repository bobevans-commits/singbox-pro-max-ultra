package com.example.proxy_app

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File

/**
 * VPN 服务实现 - 处理 TUN 模式下的数据包转发
 */
class VpnServiceImpl : VpnService() {
    private val binder = LocalBinder()
    private var parcelFileDescriptor: ParcelFileDescriptor? = null
    private var thread: Thread? = null

    inner class LocalBinder : Binder() {
        fun getService(): VpnServiceImpl = this@VpnServiceImpl
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = intent?.getStringExtra("config") ?: return START_NOT_STICKY

        // 启动前台服务
        startForeground(1, createNotification())

        // 在后台线程中启动 VPN
        thread = Thread {
            try {
                setupVpn(config)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        thread?.start()

        return START_STICKY
    }

    private fun setupVpn(config: String) {
        // 创建 TUN 设备
        val builder = Builder()
            .setSession("ProxyVPN")
            .addAddress("10.8.9.1", 24)
            .addDnsServer("8.8.8.8")
            .addDnsServer("1.1.1.1")
            .addRoute("0.0.0.0", 0)
            .setMtu(1500)
            .setBlocking(false)

        // Android 10+ 需要设置 Metered
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        parcelFileDescriptor = builder.establish()
        
        if (parcelFileDescriptor == null) {
            throw IllegalStateException("Failed to establish VPN connection")
        }

        val fd = parcelFileDescriptor!!.fd
        
        // TODO: 这里需要调用实际的内核库来启动数据转发
        // 目前只是占位，实际需要：
        // 1. 通过 JNI 调用 sing-box/mihomo/v2ray 的库
        // 2. 传递文件描述符和配置
        // 3. 启动数据转发循环
        
        println("VPN established with fd: $fd")
        println("Config: ${config.take(100)}...")
        
        // 模拟运行
        while (!Thread.interrupted()) {
            Thread.sleep(1000)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
    }

    private fun stopVpn() {
        thread?.interrupt()
        thread = null
        
        parcelFileDescriptor?.close()
        parcelFileDescriptor = null
    }

    override fun onRevoke() {
        // VPN 权限被撤销
        stopVpn()
        stopSelf()
    }

    private fun createNotification(): android.app.Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, "vpn_channel")
            .setContentTitle("代理服务运行中")
            .setContentText("点击打开应用")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannelCompat.Builder(
            "vpn_channel",
            NotificationManagerCompat.IMPORTANCE_LOW
        )
            .setName("VPN Service")
            .setDescription("VPN service notification")
            .build()

        NotificationManagerCompat.from(this).createNotificationChannel(channel)
    }
}
