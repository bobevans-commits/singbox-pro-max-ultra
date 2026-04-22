package com.example.proxy_app

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val vpnRequestCode = 1000
    private var pendingResult: MethodChannel.Result? = null
    private var configJson: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册内核代理方法通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kernel_proxy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startKernel" -> handleStartKernel(call, result)
                    "stopKernel" -> handleStopKernel(result)
                    "checkVpnPermission" -> checkVpnPermission(result)
                    "requestVpnPermission" -> requestVpnPermission(result)
                    "startTunDevice" -> handleStartTunDevice(call, result)
                    "stopTunDevice" -> handleStopTunDevice(result)
                    "setSystemProxy" -> handleSetSystemProxy(call, result)
                    "getKernelStatus" -> getKernelStatus(result)
                    "getLogs" -> getLogs(call, result)
                    "clearLogs" -> clearLogs(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleStartKernel(call: MethodCall, result: MethodChannel.Result) {
        val configPath = call.argument<String>("configPath")
        val kernelType = call.argument<String>("kernelType")
        val tunMode = call.argument<Boolean>("tunMode") ?: false

        if (configPath == null || kernelType == null) {
            result.error("INVALID_ARGS", "Missing required arguments", null)
            return
        }

        if (tunMode) {
            // TUN 模式需要先请求 VPN 权限
            configJson = File(configPath).readText()
            pendingResult = result
            requestVpnPermissionInternal()
        } else {
            // 普通代理模式
            startProxyService(configPath, kernelType)
            result.success(true)
        }
    }

    private fun handleStartTunDevice(call: MethodCall, result: MethodChannel.Result) {
        val configPath = call.argument<String>("configPath")
        
        if (configPath == null) {
            result.error("INVALID_ARGS", "Missing configPath", null)
            return
        }

        configJson = File(configPath).readText()
        pendingResult = result
        requestVpnPermissionInternal()
    }

    private fun requestVpnPermissionInternal() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, vpnRequestCode)
        } else {
            onActivityResult(vpnRequestCode, RESULT_OK, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == vpnRequestCode) {
            if (resultCode == RESULT_OK && configJson != null) {
                startVpnService(configJson!!)
                pendingResult?.success(true)
                pendingResult = null
            } else {
                pendingResult?.error("PERMISSION_DENIED", "User denied VPN permission", null)
                pendingResult = null
            }
        }
    }

    private fun startVpnService(config: String) {
        val intent = Intent(this, VpnServiceImpl::class.java)
        intent.putExtra("config", config)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun startProxyService(configPath: String, kernelType: String) {
        val intent = Intent(this, ProxyService::class.java)
        intent.putExtra("config_path", configPath)
        intent.putExtra("kernel_type", kernelType)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun handleStopKernel(result: MethodChannel.Result) {
        stopService(Intent(this, VpnServiceImpl::class.java))
        stopService(Intent(this, ProxyService::class.java))
        result.success(true)
    }

    private fun handleStopTunDevice(result: MethodChannel.Result) {
        stopService(Intent(this, VpnServiceImpl::class.java))
        result.success(true)
    }

    private fun checkVpnPermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        result.success(intent == null)
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, vpnRequestCode)
            result.success(true) // 已启动请求，返回 true 表示流程已开始
        } else {
            result.success(true) // 已有权限
        }
    }

    private fun handleSetSystemProxy(call: MethodCall, result: MethodChannel.Result) {
        val enable = call.argument<Boolean>("enable") ?: false
        val host = call.argument<String>("host") ?: ""
        val port = call.argument<Int>("port") ?: 0
        
        // Android 通常不需要手动设置系统代理，由 VPN 服务处理
        result.success(true)
    }

    private fun getKernelStatus(result: MethodChannel.Result) {
        // TODO: 从服务获取实际状态
        result.success(mapOf(
            "running" to false,
            "mode" to "proxy"
        ))
    }

    private fun getLogs(call: MethodCall, result: MethodChannel.Result) {
        val limit = call.argument<Int>("limit") ?: 100
        // TODO: 从日志文件读取
        result.success(emptyList<String>())
    }

    private fun clearLogs(result: MethodChannel.Result) {
        // TODO: 清空日志文件
        result.success(true)
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
