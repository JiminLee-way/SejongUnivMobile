package sejong.sejong_univ_station

import sejong.sejong_univ_station.nfc.S1PassManager
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val secureChannelName = "ac.sejong/secure_screen"
    private val s1passChannelName = "ac.sejong/s1pass"
    private val diagnosticsChannelName = "ac.sejong/diagnostics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── FLAG_SECURE — 학생증 화면 스크린샷 차단 ───────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        runOnUiThread {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE,
                            )
                        }
                        result.success(null)
                    }
                    "disable" -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── S1Pass NFC HCE — cardNo 저장 + ForegroundService 제어 ────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, s1passChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCardNo" -> {
                        val cardNo = call.argument<String>("cardNo")
                        if (cardNo.isNullOrBlank()) {
                            result.error("EMPTY_CARD", "cardNo is empty", null)
                            return@setMethodCallHandler
                        }
                        S1PassManager.setCardNo(applicationContext, cardNo)
                        result.success(null)
                    }
                    "clearCardNo" -> {
                        S1PassManager.clearCardNo(applicationContext)
                        result.success(null)
                    }
                    "startService" -> {
                        S1PassManager.startService(applicationContext)
                        result.success(S1PassManager.isServiceRunning())
                    }
                    "stopService" -> {
                        S1PassManager.stopService(applicationContext)
                        result.success(null)
                    }
                    "isNfcSupported" -> {
                        result.success(S1PassManager.isNfcSupported(applicationContext))
                    }
                    "isNfcEnabled" -> {
                        result.success(S1PassManager.isNfcEnabled(applicationContext))
                    }
                    "isServiceRunning" -> {
                        result.success(S1PassManager.isServiceRunning())
                    }
                    "hasCardNo" -> {
                        result.success(S1PassManager.getCardNo(applicationContext) != null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── Process exit diagnostics — Android 11+ ApplicationExitInfo ─────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, diagnosticsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRecentExitInfo" -> {
                        try {
                            result.success(getRecentExitInfo())
                        } catch (e: Exception) {
                            result.error(
                                "EXIT_INFO_FAILED",
                                e.message ?: "Failed to read process exit info",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getRecentExitInfo(): List<Map<String, Any?>> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager
            .getHistoricalProcessExitReasons(packageName, 0, 8)
            .map { info ->
                mapOf(
                    "reason" to info.reason,
                    "reasonName" to reasonName(info.reason),
                    "timestamp" to info.timestamp,
                    "description" to info.description,
                    "importance" to info.importance,
                    "status" to info.status,
                    "processName" to info.processName,
                )
            }
    }

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_UNKNOWN -> "REASON_UNKNOWN"
        ApplicationExitInfo.REASON_EXIT_SELF -> "REASON_EXIT_SELF"
        ApplicationExitInfo.REASON_SIGNALED -> "REASON_SIGNALED"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "REASON_LOW_MEMORY"
        ApplicationExitInfo.REASON_CRASH -> "REASON_CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "REASON_CRASH_NATIVE"
        ApplicationExitInfo.REASON_ANR -> "REASON_ANR"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "REASON_INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "REASON_PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE ->
            "REASON_EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "REASON_USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "REASON_USER_STOPPED"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "REASON_DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_OTHER -> "REASON_OTHER"
        ApplicationExitInfo.REASON_FREEZER -> "REASON_FREEZER"
        ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "REASON_PACKAGE_STATE_CHANGE"
        ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "REASON_PACKAGE_UPDATED"
        else -> "REASON_$reason"
    }
}
