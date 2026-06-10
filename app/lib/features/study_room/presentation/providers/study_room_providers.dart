import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/study_room/data/datasources/sejong_study_room_remote.dart';
import 'package:sejong_smart_campus/features/study_room/domain/entities/study_room_models.dart';

final _studyRoomRemoteProvider = FutureProvider<SejongStudyRoomRemote>((
  ref,
) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongStudyRoomRemote(client: client);
});

final studyRoomStatusProvider = FutureProvider<List<StudyRoomStatus>>((
  ref,
) async {
  final remote = await ref.watch(_studyRoomRemoteProvider.future);
  return remote.fetchStatus();
});

final myStudyRoomReservationsProvider =
    FutureProvider<List<StudyRoomReservation>>((ref) async {
      ref.watch(currentUserProvider);
      final remote = await ref.watch(_studyRoomRemoteProvider.future);
      return remote.fetchMyReservations();
    });
