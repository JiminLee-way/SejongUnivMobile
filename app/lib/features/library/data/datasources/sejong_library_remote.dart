import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';

class LibraryLoanInfo {
  const LibraryLoanInfo({
    required this.loanCount,
    required this.overDueCount,
    required this.reserveCount,
  });
  final int loanCount;
  final int overDueCount;
  final int reserveCount;
  bool get hasAny => loanCount > 0 || overDueCount > 0 || reserveCount > 0;
}

class SejongLibraryRemote {
  SejongLibraryRemote({required this.client});
  final SejongApiClient client;

  Future<LibraryLoanInfo> fetchLoanInfo() async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.libraryLoanInfo);
    return client.unwrap<LibraryLoanInfo>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      int n(String key) => ((m[key] as num?) ?? 0).toInt();
      return LibraryLoanInfo(
        loanCount: n('loanCount'),
        overDueCount: n('overDueCount'),
        reserveCount: n('reserveCount'),
      );
    });
  }
}
