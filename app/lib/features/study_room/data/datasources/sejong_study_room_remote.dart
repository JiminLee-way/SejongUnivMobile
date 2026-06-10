import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/study_room/domain/entities/study_room_models.dart';

class SejongStudyRoomRemote {
  SejongStudyRoomRemote({required this.client});
  final SejongApiClient client;

  Future<List<StudyRoomStatus>> fetchStatus() async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.publicApi}/study-room/status',
    );
    return client.unwrap<List<StudyRoomStatus>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(StudyRoomStatus.fromJson)
          .toList();
    });
  }

  Future<List<StudyRoomReservation>> fetchMyReservations() async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.secureApi}/study-room/reservations',
    );
    return client.unwrap<List<StudyRoomReservation>>(res, (raw) {
      if (raw is Map<String, dynamic>) {
        final list = (raw['reservations'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map(StudyRoomReservation.fromJson)
            .toList();
      }
      if (raw is List) {
        return raw
            .cast<Map<String, dynamic>>()
            .map(StudyRoomReservation.fromJson)
            .toList();
      }
      return const [];
    });
  }
}
