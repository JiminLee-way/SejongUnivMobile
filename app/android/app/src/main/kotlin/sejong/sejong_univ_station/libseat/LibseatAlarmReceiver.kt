package sejong.sejong_univ_station.libseat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LibseatAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LibseatAlarmManager.showNotification(context, intent)
    }
}
