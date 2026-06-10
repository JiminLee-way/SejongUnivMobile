package sejong.sejong_univ_station.nfc

import sejong.sejong_univ_station.R
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * 앱 프로세스를 살려두는 ForegroundService — [S1PassHceService]가
 * 앱이 background거나 화면이 꺼진 상태에서도 APDU 응답할 수 있게.
 *
 * 표시 알림: "모바일 학생증 — NFC 태그를 사용할 수 있습니다"
 * Android 13+ POST_NOTIFICATIONS 권한 + Android 14+ FGS_TYPE_CONNECTED_DEVICE.
 */
class S1PassForegroundService : Service() {

    companion object {
        private const val TAG = "S1Pass"
        const val CHANNEL_ID = "s1pass_channel"
        const val CHANNEL_NAME = "모바일 학생증 NFC"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning = false
            private set

        /** 매니페스트에 channel 정의하기 어려우니 첫 실행 시 등록 — idempotent. */
        fun ensureChannel(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = nm.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "NFC 출입게이트 태깅 가능 상태 표시"
                    setShowBadge(false)
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "ForegroundService onStartCommand")
        val notification = buildNotification()
        val fgType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, fgType)
        isRunning = true
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        Log.d(TAG, "ForegroundService destroyed")
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_app)
            .setColor(0xFFC8102E.toInt()) // brand red
            .setContentTitle("모바일 학생증")
            .setContentText("NFC 태그를 사용할 수 있습니다")
            .setOngoing(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
}
