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
        
        // 启动外部内核进程（sing-box/mihomo/v2ray）
        startKernelProcess(fd, config)
    }

    private fun startKernelProcess(fd: Int, config: String) {
        try {
            // 获取应用内部存储目录
            val filesDir = applicationContext.filesDir
            val kernelDir = File(filesDir, "kernels")
            
            // 确定要使用的内核（从配置或 SharedPreferences 读取）
            val kernelName = getSelectedKernel() // sing-box, mihomo, 或 v2ray
            val kernelPath = File(kernelDir, getKernelBinaryName(kernelName))
            
            if (!kernelPath.exists()) {
                throw IllegalStateException("Kernel binary not found: ${kernelPath.absolutePath}")
            }
            
            // 使内核文件可执行
            kernelPath.setExecutable(true)
            
            // 写入配置文件到临时文件
            val configFile = File(filesDir, "config.json")
            configFile.writeText(config)
            
            // 构建命令参数
            val cmd = when (kernelName) {
                "sing-box" -> arrayOf(
                    kernelPath.absolutePath,
                    "run",
                    "-c", configFile.absolutePath
                )
                "mihomo" -> arrayOf(
                    kernelPath.absolutePath,
                    "-d", filesDir.absolutePath,
                    "-f", configFile.absolutePath
                )
                "v2ray" -> arrayOf(
                    kernelPath.absolutePath,
                    "-config", configFile.absolutePath
                )
                else -> throw IllegalArgumentException("Unknown kernel: $kernelName")
            }
            
            // 使用 ProcessBuilder 启动内核进程，传递 TUN 文件描述符
            val processBuilder = ProcessBuilder(*cmd)
            processBuilder.environment()["PROXY_TUN_FD"] = fd.toString()
            processBuilder.environment()["PROXY_APP_DIR"] = filesDir.absolutePath
            
            // 启动进程
            val process = processBuilder.start()
            
            println("Kernel process started: ${kernelPath.name} (PID: ${process.pid()})")
            println("TUN FD: $fd")
            
            // 等待进程结束
            val exitCode = process.waitFor()
            println("Kernel process exited with code: $exitCode")
            
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }
    
    private fun getSelectedKernel(): String {
        val prefs = getSharedPreferences("proxy_settings", MODE_PRIVATE)
        return prefs.getString("selected_kernel", "sing-box") ?: "sing-box"
    }
    
    private fun getKernelBinaryName(kernelName: String): String {
        return when (kernelName) {
            "sing-box" -> "sing-box"
            "mihomo" -> "mihomo"
            "v2ray" -> "v2ray"
            else -> kernelName
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
