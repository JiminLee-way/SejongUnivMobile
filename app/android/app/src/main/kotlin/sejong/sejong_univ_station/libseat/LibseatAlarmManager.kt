package sejong.sejong_univ_station.libseat

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import sejong.sejong_univ_station.MainActivity
import sejong.sejong_univ_station.R

object LibseatAlarmManager {
    private const val TAG = "LibseatAlarm"

    const val CHANNEL_ID = "libseat_reminder"
    const val EXTRA_NOTIFICATION_PAYLOAD = "notification_payload"

    private const val PREFS = "libseat_alarm_state"
    private const val KEY_ACTIVE = "active"
    private const val KEY_ROOM_NAME = "roomName"
    private const val KEY_ROOM_NO = "roomNo"
    private const val KEY_SEAT_NO = "seatNo"
    private const val KEY_STARTED_AT = "startedAtMillis"
    private const val KEY_EXPIRES_AT = "expiresAtMillis"
    private const val KEY_RESERVATION_KEY = "reservationKey"
    private const val KEY_REMINDERS_ENABLED = "remindersEnabled"
    private const val KEY_ENABLED_MINUTES = "enabledMinutesBefore"
    private const val KEY_SCHEDULED_IDS = "scheduledIds"
    private const val KEY_VERSION_CODE = "versionCode"

    private const val ACTION_ALARM_PREFIX =
        "sejong.sejong_univ_station.libseat.ALARM"
    private const val ACTION_NOTIFICATION_TAP =
        "sejong.sejong_univ_station.libseat.NOTIFICATION_TAP"

    private const val ID_EXTEND = 70020
    private const val ID_60 = 70060
    private const val ID_45 = 70045
    private const val ID_30 = 70030
    private const val ID_25 = 70025
    private const val ID_20 = 70022
    private const val ID_15 = 70015
    private const val ID_10 = 70010
    private const val ID_5 = 70005
    private val allIds = listOf(
        ID_EXTEND,
        ID_60,
        ID_45,
        ID_30,
        ID_25,
        ID_20,
        ID_15,
        ID_10,
        ID_5,
    )
    private val defaultMinutes = setOf(5, 15, 30, 60, 120)
    private val supportedMinutes = setOf(5, 10, 15, 20, 25, 30, 45, 60, 120)

    data class Snapshot(
        val roomName: String,
        val roomNo: Int,
        val seatNo: String,
        val startedAtMillis: Long,
        val expiresAtMillis: Long,
        val reservationKey: String,
        val remindersEnabled: Boolean = true,
        val enabledMinutesBefore: Set<Int> = setOf(5, 15, 30, 60, 120),
    ) {
        val hasAnyReminder: Boolean
            get() = remindersEnabled && enabledMinutesBefore.isNotEmpty()

        fun hasSameSchedule(other: Snapshot): Boolean =
            reservationKey == other.reservationKey &&
                startedAtMillis == other.startedAtMillis &&
                expiresAtMillis == other.expiresAtMillis &&
                remindersEnabled == other.remindersEnabled &&
                enabledMinutesBefore == other.enabledMinutesBefore
    }

    private data class AlarmSpec(
        val kind: String,
        val id: Int,
        val fireAtMillis: Long,
        val title: String,
        val body: String,
        val payload: String,
    )

    fun snapshotFromMap(args: Map<*, *>): Snapshot {
        return Snapshot(
            roomName = stringArg(args, "roomName"),
            roomNo = longArg(args, "roomNo").toInt(),
            seatNo = stringArg(args, "seatNo"),
            startedAtMillis = longArg(args, "startedAtMillis"),
            expiresAtMillis = longArg(args, "expiresAtMillis"),
            reservationKey = stringArg(args, "reservationKey"),
            remindersEnabled = boolArg(args, "remindersEnabled", true),
            enabledMinutesBefore = minutesArg(args, "enabledMinutesBefore"),
        )
    }

    fun schedule(context: Context, snapshot: Snapshot) {
        if (snapshot.expiresAtMillis <= System.currentTimeMillis() || !snapshot.hasAnyReminder) {
            cancel(context)
            return
        }

        ensureChannel(context)
        cancelPendingAlarms(context)

        val now = System.currentTimeMillis()
        val specs = buildPlan(snapshot, now)
        prefs(context)
            .edit()
            .putBoolean(KEY_ACTIVE, true)
            .putString(KEY_ROOM_NAME, snapshot.roomName)
            .putInt(KEY_ROOM_NO, snapshot.roomNo)
            .putString(KEY_SEAT_NO, snapshot.seatNo)
            .putLong(KEY_STARTED_AT, snapshot.startedAtMillis)
            .putLong(KEY_EXPIRES_AT, snapshot.expiresAtMillis)
            .putString(KEY_RESERVATION_KEY, snapshot.reservationKey)
            .putBoolean(KEY_REMINDERS_ENABLED, snapshot.remindersEnabled)
            .putStringSet(
                KEY_ENABLED_MINUTES,
                snapshot.enabledMinutesBefore.map { it.toString() }.toSet(),
            )
            .putStringSet(KEY_SCHEDULED_IDS, specs.map { it.id.toString() }.toSet())
            .putLong(KEY_VERSION_CODE, appVersionCode(context))
            .apply()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exactAllowed =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()
        Log.i(
            TAG,
            "schedule key=${snapshot.reservationKey} ids=${specs.map { it.id }} exact=$exactAllowed",
        )

        for (spec in specs) {
            val pendingIntent = alarmPendingIntent(context, spec.id, spec)
            if (exactAllowed) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    spec.fireAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    spec.fireAtMillis,
                    pendingIntent,
                )
            }
        }
    }

    fun hasAllPending(context: Context, snapshot: Snapshot): Boolean {
        val stored = readSnapshot(context) ?: return false
        if (!stored.hasSameSchedule(snapshot)) return false
        if (stored.expiresAtMillis <= System.currentTimeMillis()) return false
        val prefs = prefs(context)
        if (prefs.getLong(KEY_VERSION_CODE, -1L) != appVersionCode(context)) {
            return false
        }
        val scheduledIds = prefs.getStringSet(KEY_SCHEDULED_IDS, emptySet()).orEmpty()
        val expectedIds = buildPlan(snapshot, System.currentTimeMillis())
            .map { it.id.toString() }
        val covered = scheduledIds.containsAll(expectedIds)
        Log.i(
            TAG,
            "hasAllPending key=${snapshot.reservationKey} expected=$expectedIds scheduled=$scheduledIds result=$covered",
        )
        return covered
    }

    fun cancel(context: Context) {
        cancelPendingAlarms(context)
        prefs(context).edit().clear().apply()
    }

    fun rescheduleFromStorage(context: Context) {
        val snapshot = readSnapshot(context) ?: return
        if (snapshot.expiresAtMillis <= System.currentTimeMillis()) {
            cancel(context)
            return
        }
        Log.i(TAG, "rescheduleFromStorage key=${snapshot.reservationKey}")
        schedule(context, snapshot)
    }

    fun showNotification(context: Context, intent: Intent) {
        val id = intent.getIntExtra("notificationId", -1)
        if (id < 0) return
        val title = intent.getStringExtra("title") ?: "열람실 반납 알림"
        val body = intent.getStringExtra("body") ?: return
        val payload = intent.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD) ?: return

        markDelivered(context, id)
        Log.i(TAG, "showNotification id=$id payload=$payload")
        ensureChannel(context)
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_NOTIFICATION_TAP
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_NOTIFICATION_PAYLOAD, payload)
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context,
            id + 10000,
            tapIntent,
            pendingIntentFlags(),
        )

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_app)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setAutoCancel(true)
            .setContentIntent(tapPendingIntent)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, notification)
    }

    private fun buildPlan(snapshot: Snapshot, nowMillis: Long): List<AlarmSpec> {
        if (!snapshot.hasAnyReminder) return emptyList()
        val roomLabel = snapshot.roomName.trim().ifEmpty { "열람실" }
        val expiresAt = snapshot.expiresAtMillis
        return snapshot.enabledMinutesBefore
            .sortedDescending()
            .mapNotNull { minutesBefore ->
                val kind = kindForMinutes(minutesBefore) ?: return@mapNotNull null
                val id = idForMinutes(minutesBefore) ?: return@mapNotNull null
                val fireAtMillis = expiresAt - minutes(minutesBefore.toLong())
                val title: String
                val body: String
                if (minutesBefore == 120) {
                    title = "열람실 연장 가능 시각입니다"
                    body = "$roomLabel 연장 가능 시각입니다."
                } else {
                    title = "열람실 반납 알림"
                    body = "$roomLabel 반납 ${remainingLabel(minutesBefore)} 남았습니다."
                }
                if (fireAtMillis <= nowMillis) return@mapNotNull null
                AlarmSpec(
                    kind = kind,
                    id = id,
                    fireAtMillis = fireAtMillis,
                    title = title,
                    body = body,
                    payload = "libseat:$kind:${snapshot.reservationKey}",
                )
            }
    }

    private fun cancelPendingAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (id in allIds) {
            alarmManager.cancel(alarmPendingIntent(context, id, null))
            notificationManager.cancel(id)
        }
    }

    private fun markDelivered(context: Context, id: Int) {
        val prefs = prefs(context)
        val existing = prefs.getStringSet(KEY_SCHEDULED_IDS, emptySet()).orEmpty()
        val next = existing.filterNot { it == id.toString() }.toSet()
        prefs.edit().putStringSet(KEY_SCHEDULED_IDS, next).apply()
    }

    private fun alarmPendingIntent(
        context: Context,
        id: Int,
        spec: AlarmSpec?,
    ): PendingIntent {
        val intent = Intent(context, LibseatAlarmReceiver::class.java).apply {
            action = "$ACTION_ALARM_PREFIX.$id"
            if (spec != null) {
                putExtra("kind", spec.kind)
                putExtra("notificationId", spec.id)
                putExtra("title", spec.title)
                putExtra("body", spec.body)
                putExtra(EXTRA_NOTIFICATION_PAYLOAD, spec.payload)
            }
        }
        return PendingIntent.getBroadcast(context, id, intent, pendingIntentFlags())
    }

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "열람실 예약 알림",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "열람실 좌석 예약 종료 전 안내"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun readSnapshot(context: Context): Snapshot? {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_ACTIVE, false)) return null
        val roomName = prefs.getString(KEY_ROOM_NAME, null) ?: return null
        val seatNo = prefs.getString(KEY_SEAT_NO, null) ?: return null
        val reservationKey = prefs.getString(KEY_RESERVATION_KEY, null) ?: return null
        return Snapshot(
            roomName = roomName,
            roomNo = prefs.getInt(KEY_ROOM_NO, 0),
            seatNo = seatNo,
            startedAtMillis = prefs.getLong(KEY_STARTED_AT, 0L),
            expiresAtMillis = prefs.getLong(KEY_EXPIRES_AT, 0L),
            reservationKey = reservationKey,
            remindersEnabled = prefs.getBoolean(KEY_REMINDERS_ENABLED, true),
            enabledMinutesBefore = prefs
                .getStringSet(KEY_ENABLED_MINUTES, null)
                ?.mapNotNull { it.toIntOrNull() }
                ?.filter { supportedMinutes.contains(it) }
                ?.toSet()
                ?: defaultMinutes,
        )
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun pendingIntentFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun hours(value: Long): Long = value * 60L * 60L * 1000L

    private fun minutes(value: Long): Long = value * 60L * 1000L

    private fun kindForMinutes(minutesBefore: Int): String? =
        when (minutesBefore) {
            120 -> "extend"
            60 -> "60m"
            45 -> "45m"
            30 -> "30m"
            25 -> "25m"
            20 -> "20m"
            15 -> "15m"
            10 -> "10m"
            5 -> "5m"
            else -> null
        }

    private fun idForMinutes(minutesBefore: Int): Int? =
        when (minutesBefore) {
            120 -> ID_EXTEND
            60 -> ID_60
            45 -> ID_45
            30 -> ID_30
            25 -> ID_25
            20 -> ID_20
            15 -> ID_15
            10 -> ID_10
            5 -> ID_5
            else -> null
        }

    private fun remainingLabel(minutesBefore: Int): String =
        when (minutesBefore) {
            60 -> "1시간"
            120 -> "2시간"
            else -> "${minutesBefore}분"
        }

    private fun stringArg(args: Map<*, *>, key: String): String {
        val value = args[key]
        return value?.toString()
            ?: throw IllegalArgumentException("$key is required")
    }

    private fun longArg(args: Map<*, *>, key: String): Long {
        return when (val value = args[key]) {
            is Number -> value.toLong()
            is String -> value.toLong()
            else -> throw IllegalArgumentException("$key is required")
        }
    }

    private fun boolArg(args: Map<*, *>, key: String, fallback: Boolean): Boolean {
        return when (val value = args[key]) {
            is Boolean -> value
            is String -> value.toBooleanStrictOrNull() ?: fallback
            null -> fallback
            else -> fallback
        }
    }

    private fun minutesArg(args: Map<*, *>, key: String): Set<Int> {
        val value = args[key] ?: return defaultMinutes
        val raw = when (value) {
            is Iterable<*> -> value
            is IntArray -> value.toList()
            else -> return defaultMinutes
        }
        return raw
            .mapNotNull {
                when (it) {
                    is Number -> it.toInt()
                    is String -> it.toIntOrNull()
                    else -> null
                }
            }
            .filter { supportedMinutes.contains(it) }
            .toSet()
    }

    @Suppress("DEPRECATION")
    private fun appVersionCode(context: Context): Long {
        val packageInfo =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }
    }
}
