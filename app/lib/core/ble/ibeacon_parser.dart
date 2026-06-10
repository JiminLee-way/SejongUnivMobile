/// iBeacon (Apple manufacturerData 0x004C) advertising payload 파서.
///
/// payload 구조 (총 23 bytes):
/// ```
/// [0..1]   = 0x02 0x15        // iBeacon proximity prefix (sub-type + length)
/// [2..17]  = UUID (16 bytes)  // big-endian, 8-4-4-4-12 포맷
/// [18..19] = Major (uint16 BE)
/// [20..21] = Minor (uint16 BE)
/// [22]     = TxPower (int8 signed) — 1m 거리 RSSI 캘리브레이션 값
/// ```
///
/// UCheck 서버는 `attendCheck.do` 페이로드에 `bc_uuid40`/`bc_major40`/`bc_minor40`/
/// `tx_power`를 그대로 받는다. 거리 추정은 클라이언트가 안 함 — 서버가 처리.
class IBeacon {
  const IBeacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPower,
  });

  /// 8-4-4-4-12 hex 포맷, 소문자 (`abcdef01-1234-5678-9abc-def012345678`).
  final String uuid;
  final int major;
  final int minor;
  final int txPower;

  @override
  String toString() =>
      'IBeacon($uuid, major=$major, minor=$minor, txPower=$txPower)';
}

/// Apple manufacturerId.
const int kIBeaconManufacturerId = 0x004C;

/// 0x004C manufacturerData → IBeacon. 잘못된 포맷이면 null.
IBeacon? parseIBeacon(List<int> manufacturerData) {
  if (manufacturerData.length < 23) return null;
  if (manufacturerData[0] != 0x02 || manufacturerData[1] != 0x15) return null;

  final uuidBytes = manufacturerData.sublist(2, 18);
  final major = (manufacturerData[18] << 8) | manufacturerData[19];
  final minor = (manufacturerData[20] << 8) | manufacturerData[21];
  // signed byte
  final txPowerRaw = manufacturerData[22];
  final txPower = txPowerRaw > 127 ? txPowerRaw - 256 : txPowerRaw;

  return IBeacon(
    uuid: _formatUuid(uuidBytes),
    major: major,
    minor: minor,
    txPower: txPower,
  );
}

String _formatUuid(List<int> bytes) {
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  // 8-4-4-4-12
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20, 32)}';
}
