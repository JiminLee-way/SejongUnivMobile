/// 재정 도메인 — 장학금 · 등록금 · 자율경비.
library;

class FinanceSemester {
  const FinanceSemester({required this.year, required this.smtCd});
  final String year;
  final String smtCd;
  String get label {
    final tail = switch (smtCd) {
      '10' => '1학기',
      '11' => '여름학기',
      '20' => '2학기',
      '21' => '겨울학기',
      _ => smtCd,
    };
    return '$year년 $tail';
  }

  factory FinanceSemester.fromJson(Map<String, dynamic> json) =>
      FinanceSemester(
        year: (json['year'] ?? '').toString(),
        smtCd: (json['smtCd'] ?? '').toString(),
      );
}

// ─── 장학금 ────────────────────────────────────────────────────────────────

class ScholarshipItem {
  const ScholarshipItem({
    required this.scholarshipName,
    required this.admissionFee,
    required this.tuitionFee,
    required this.supportFee,
    required this.totalAmount,
  });
  final String scholarshipName;
  final int admissionFee;
  final int tuitionFee;
  final int supportFee;
  final int totalAmount;

  factory ScholarshipItem.fromJson(Map<String, dynamic> json) =>
      ScholarshipItem(
        scholarshipName: (json['scholarshipName'] ?? '').toString(),
        admissionFee: ((json['admissionFee'] as num?) ?? 0).toInt(),
        tuitionFee: ((json['tuitionFee'] as num?) ?? 0).toInt(),
        supportFee: ((json['supportFee'] as num?) ?? 0).toInt(),
        totalAmount: ((json['totalAmount'] as num?) ?? 0).toInt(),
      );
}

// ─── 등록금 ────────────────────────────────────────────────────────────────

class TuitionItem {
  const TuitionItem({
    required this.yearSmtInfo,
    required this.deptNm,
    required this.studentNo,
    required this.nm,
    required this.rgstEntAmt,
    required this.rgstLessAmt,
    required this.totSchoAmt,
    required this.totDemandAmt,
    required this.virtBankNo,
    required this.resAmt,
  });
  final String yearSmtInfo;
  final String deptNm;
  final String studentNo;
  final String nm;
  final int rgstEntAmt;
  final int rgstLessAmt;
  final int totSchoAmt;
  final int totDemandAmt;
  final String virtBankNo;
  final int resAmt;

  factory TuitionItem.fromJson(Map<String, dynamic> json) => TuitionItem(
    yearSmtInfo: (json['yearSmtInfo'] ?? '').toString(),
    deptNm: (json['deptNm'] ?? '').toString(),
    studentNo: (json['studentNo'] ?? '').toString(),
    nm: (json['nm'] ?? '').toString(),
    rgstEntAmt: ((json['rgstEntAmt'] as num?) ?? 0).toInt(),
    rgstLessAmt: ((json['rgstLessAmt'] as num?) ?? 0).toInt(),
    totSchoAmt: ((json['totSchoAmt'] as num?) ?? 0).toInt(),
    totDemandAmt: ((json['totDemandAmt'] as num?) ?? 0).toInt(),
    virtBankNo: (json['virtBankNo'] ?? '').toString(),
    resAmt: ((json['resAmt'] as num?) ?? 0).toInt(),
  );
}

// ─── 자율경비 ──────────────────────────────────────────────────────────────

class DiscretionaryItem {
  const DiscretionaryItem({
    required this.name,
    required this.billedAmount,
    required this.paidAmount,
  });
  final String name;
  final int billedAmount;
  final int paidAmount;

  factory DiscretionaryItem.fromJson(Map<String, dynamic> json) =>
      DiscretionaryItem(
        name: (json['name'] ?? '').toString(),
        billedAmount: ((json['billedAmount'] as num?) ?? 0).toInt(),
        paidAmount: ((json['paidAmount'] as num?) ?? 0).toInt(),
      );
}

class DiscretionaryGroup {
  const DiscretionaryGroup({
    required this.label,
    required this.items,
    required this.totalBilled,
    required this.totalPaid,
  });
  final String label;
  final List<DiscretionaryItem> items;
  final int totalBilled;
  final int totalPaid;

  factory DiscretionaryGroup.fromJson(Map<String, dynamic> json) =>
      DiscretionaryGroup(
        label: (json['label'] ?? '').toString(),
        items: ((json['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DiscretionaryItem.fromJson)
            .toList(),
        totalBilled: ((json['totalBilled'] as num?) ?? 0).toInt(),
        totalPaid: ((json['totalPaid'] as num?) ?? 0).toInt(),
      );
}
