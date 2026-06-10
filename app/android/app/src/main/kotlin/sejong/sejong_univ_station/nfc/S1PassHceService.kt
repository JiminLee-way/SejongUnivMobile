package sejong.sejong_univ_station.nfc

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

/**
 * 세종대 캠퍼스 NFC 리더(도서관 출입 게이트 등)와 통신하는 HCE 서비스.
 *
 * 리더가 SELECT APDU(`00 A4 04 00 07 FF 73 70 70 73 6A 67`)를 보내면
 * `S1PassManager`에 저장된 `cardNo` UTF-8 bytes + `0x9000`(OK SW) 응답.
 * 잘못된 APDU 또는 cardNo 없으면 `0x6900` 에러 SW.
 *
 * **앱이 종료된 상태에서도 OS가 이 서비스를 깨워 호출**한다
 * (registered HCE service의 본질). 단, "잠금 화면에서도 작동"은
 * `s1pass_aid_list.xml`의 `requireDeviceUnlock=false` + `requireDeviceScreenOn=false`로 보장.
 *
 * AID = FF737070736A67 (ASCII "sppsjg") — 공식 값.
 */
class S1PassHceService : HostApduService() {

    companion object {
        private const val TAG = "S1Pass"

        // Status words
        private val SELECT_OK_SW = byteArrayOf(0x90.toByte(), 0x00)
        private val UNKNOWN_CMD_SW = byteArrayOf(0x69.toByte(), 0x00)

        // SELECT APDU header: 00 A4 04 00
        private const val SELECT_APDU_HEADER = "00A40400"

        // AID: FF737070736A67 (ASCII "sppsjg")
        private const val AID = "FF737070736A67"

        // Full expected hex prefix: header + Lc(07) + AID
        private const val SELECT_APDU_HEX = SELECT_APDU_HEADER + "07" + AID

        // Minimum APDU byte length: header(5) + AID(7) = 12
        private const val MIN_SELECT_APDU_SIZE = 12

        // 중복 태깅 방지 — 같은 리더가 빠르게 두 번 호출하는 케이스 차단.
        private const val APDU_DEBOUNCE_MS = 500L
    }

    private var lastResponseTime = 0L

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        Log.d(TAG, "APDU received: ${commandApdu.toHexString()}")

        if (!isSelectApdu(commandApdu)) {
            Log.d(TAG, "Not a SELECT APDU, returning error")
            return UNKNOWN_CMD_SW
        }

        val now = System.currentTimeMillis()
        if (now - lastResponseTime < APDU_DEBOUNCE_MS) {
            Log.d(TAG, "Debounce: ignoring duplicate read")
            return UNKNOWN_CMD_SW
        }

        val cardNo = S1PassManager.getCardNo(this)
        if (cardNo.isNullOrBlank()) {
            Log.w(TAG, "No cardNo stored, returning error")
            return UNKNOWN_CMD_SW
        }

        lastResponseTime = now
        val response = cardNo.toByteArray(Charsets.UTF_8) + SELECT_OK_SW
        Log.d(TAG, "Responding with cardNo: ${cardNo.take(4)}**** (${response.size} bytes)")
        return response
    }

    override fun onDeactivated(reason: Int) {
        val reasonStr = when (reason) {
            DEACTIVATION_LINK_LOSS -> "LINK_LOSS"
            DEACTIVATION_DESELECTED -> "DESELECTED"
            else -> "UNKNOWN($reason)"
        }
        Log.d(TAG, "NFC deactivated: $reasonStr")
    }

    private fun isSelectApdu(apdu: ByteArray): Boolean =
        apdu.size >= MIN_SELECT_APDU_SIZE &&
            apdu.toHexString().uppercase().startsWith(SELECT_APDU_HEX)

    private fun ByteArray.toHexString(): String =
        joinToString("") { "%02X".format(it) }
}
