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
        try {
            // 获取应用内部存储目录
            val filesDir = applicationContext.filesDir
            val kernelDir = File(filesDir, "kernels")
            
            // 确定内核二进制文件路径
            val kernelPath = File(kernelDir, getKernelBinaryName(kernelType))
            
            if (!kernelPath.exists()) {
                throw IllegalStateException("Kernel binary not found: ${kernelPath.absolutePath}")
            }
            
            // 使内核文件可执行
            kernelPath.setExecutable(true)
            
            // 读取配置文件
            val configFile = File(configPath)
            if (!configFile.exists()) {
                throw IllegalStateException("Config file not found: $configPath")
            }
            
            // 构建命令参数
            val cmd = when (kernelType) {
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
                else -> throw IllegalArgumentException("Unknown kernel: $kernelType")
            }
            
            // 使用 ProcessBuilder 启动内核进程
            val processBuilder = ProcessBuilder(*cmd)
            processBuilder.environment()["PROXY_APP_DIR"] = filesDir.absolutePath
            processBuilder.redirectErrorStream(true)
            
            // 启动进程
            val process = processBuilder.start()
            
            println("Proxy process started: ${kernelPath.name} (PID: ${process.pid()})")
            
            // 读取日志输出
            Thread {
                process.inputStream.bufferedReader().use { reader ->
                    while (true) {
                        val line = reader.readLine() ?: break
                        println("[${kernelType}] $line")
                        // TODO: 将日志发送到 Flutter 层
                    }
                }
            }.start()
            
            // 等待进程结束
            val exitCode = process.waitFor()
            println("Proxy process exited with code: $exitCode")
            
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }
    
    private fun getKernelBinaryName(kernelType: String): String {
        return when (kernelType) {
            "sing-box" -> "sing-box"
            "mihomo" -> "mihomo"
            "v2ray" -> "v2ray"
            else -> kernelType
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
