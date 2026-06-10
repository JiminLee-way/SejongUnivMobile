package sejong.sejong_univ_station.nfc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 디바이스 부팅 직후 자동으로 S1PassForegroundService 시작 — 사용자가
 * 앱을 한 번도 안 켜도 NFC 태깅 작동 보장.
 *
 * 단, cardNo가 secure prefs에 저장돼있어야 (= 한 번이라도 로그인했어야)
 * S1PassManager.startService가 실제로 시작. 첫 설치 후 로그인 전이면
 * cardNo가 없어 silent skip.
 */
class S1PassBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "S1Pass"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) return

        Log.d(TAG, "Boot completed — attempting to start S1Pass service")
        S1PassManager.startService(context)
    }
}
