package sejong.sejong_univ_station.nfc

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * S1Pass cardNo 저장소 + ForegroundService 제어.
 *
 * `EncryptedSharedPreferences`로 cardNo를 디스크에 안전 보관 — 앱이 죽거나
 * 디바이스 재부팅되어도 HCE service가 cardNo를 즉시 읽어 응답할 수 있다.
 *
 * **모든 메서드 process-wide singleton 안전** — 동기 in-memory cache + 디스크 sync.
 */
object S1PassManager {
    private const val TAG = "S1Pass"
    private const val PREF_FILE = "s1pass_prefs"
    private const val KEY_CARD_NO = "card_no"

    @Volatile
    private var cachedCardNo: String? = null

    fun setCardNo(context: Context, cardNo: String) {
        if (cardNo.isBlank()) return
        cachedCardNo = cardNo
        getPrefs(context).edit().putString(KEY_CARD_NO, cardNo).apply()
        Log.d(TAG, "cardNo saved: ${cardNo.take(4)}****")
    }

    fun getCardNo(context: Context): String? {
        cachedCardNo?.let { return it }
        val stored = getPrefs(context).getString(KEY_CARD_NO, null)
        cachedCardNo = stored
        return stored
    }

    fun clearCardNo(context: Context) {
        cachedCardNo = null
        getPrefs(context).edit().remove(KEY_CARD_NO).apply()
        Log.d(TAG, "cardNo cleared")
    }

    fun isNfcSupported(context: Context): Boolean =
        NfcAdapter.getDefaultAdapter(context) != null

    fun isNfcEnabled(context: Context): Boolean =
        NfcAdapter.getDefaultAdapter(context)?.isEnabled == true

    /**
     * S1PassForegroundService 시작. cardNo가 저장돼있고 POST_NOTIFICATIONS
     * 권한이 있을 때만. 이미 실행 중이면 idempotent.
     */
    fun startService(context: Context) {
        val cardNo = getCardNo(context)
        if (cardNo.isNullOrBlank()) {
            Log.w(TAG, "Cannot start service: no cardNo")
            return
        }
        // Android 13+: POST_NOTIFICATIONS 권한 없으면 ForegroundService 시작 시 크래시
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Cannot start service: POST_NOTIFICATIONS not granted")
            return
        }
        val intent = Intent(context, S1PassForegroundService::class.java)
        context.startForegroundService(intent)
        Log.d(TAG, "ForegroundService start requested")
    }

    fun stopService(context: Context) {
        val intent = Intent(context, S1PassForegroundService::class.java)
        context.stopService(intent)
        Log.d(TAG, "ForegroundService stop requested")
    }

    fun isServiceRunning(): Boolean = S1PassForegroundService.isRunning

    private fun getPrefs(context: Context) =
        EncryptedSharedPreferences.create(
            context,
            PREF_FILE,
            MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
}
