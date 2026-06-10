package sejong.sejong_univ_station

import sejong.sejong_univ_station.nfc.S1PassManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val secureChannelName = "ac.sejong/secure_screen"
    private val s1passChannelName = "ac.sejong/s1pass"

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
    }
}
