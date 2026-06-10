import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/finance/domain/entities/finance_models.dart';

class SejongFinanceRemote {
  SejongFinanceRemote({required this.client});
  final SejongApiClient client;

  Future<List<FinanceSemester>> fetchScholarshipSemesters() async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.secureApi}/scholarship/year-semester-options',
    );
    return client.unwrap<List<FinanceSemester>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(FinanceSemester.fromJson)
          .toList();
    });
  }

  Future<List<ScholarshipItem>> fetchScholarships({
    required String year,
    required String smtCd,
  }) async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.secureApi}/scholarship/list',
      queryParameters: {'year': year, 'smtCd': smtCd},
    );
    return client.unwrap<List<ScholarshipItem>>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return ((m['scholarships'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ScholarshipItem.fromJson)
          .toList();
    });
  }

  Future<List<TuitionItem>> fetchTuitionNotice({
    required String year,
    required String smtCd,
  }) async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.secureApi}/tuition/notice',
      queryParameters: {'year': year, 'smtCd': smtCd},
    );
    return client.unwrap<List<TuitionItem>>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return ((m['tuitions'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(TuitionItem.fromJson)
          .toList();
    });
  }

  Future<List<DiscretionaryGroup>> fetchDiscretionary({
    required String year,
    required String smtCd,
  }) async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.secureApi}/discretionary-spending/detail',
      queryParameters: {'year': year, 'smtCd': smtCd},
    );
    return client.unwrap<List<DiscretionaryGroup>>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return ((m['groups'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DiscretionaryGroup.fromJson)
          .toList();
    });
  }
}
