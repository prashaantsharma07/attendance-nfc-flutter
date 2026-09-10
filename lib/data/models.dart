class SchoolClass {
  final int? id;
  final String name;

  SchoolClass({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory SchoolClass.fromMap(Map<String, dynamic> map) {
    return SchoolClass(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
    );
  }

  SchoolClass copyWith({int? id, String? name}) {
    return SchoolClass(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

class Student {
  final int? id;
  final String? rfidUid;
  final String? barcode;
  final String name;
  final String rollNo;

  Student({
    this.id,
    this.rfidUid,
    this.barcode,
    required this.name,
    required this.rollNo,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'rfidUid': rfidUid?.trim().isEmpty == true ? null : rfidUid?.trim(),
      'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      'name': name.trim(),
      'rollNo': rollNo.trim(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      rfidUid: map['rfidUid'] as String?,
      barcode: map['barcode'] as String?,
      name: map['name'] as String? ?? '',
      rollNo: map['rollNo'] as String? ?? '',
    );
  }

  Student copyWith({
    int? id,
    String? rfidUid,
    String? barcode,
    String? name,
    String? rollNo,
  }) {
    return Student(
      id: id ?? this.id,
      rfidUid: rfidUid ?? this.rfidUid,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
    );
  }
}

class AttendanceRecord {
  final int? id;
  final int classId;
  final int studentId;
  final String dateKey; // yyyy-MM-dd
  final int timestamp; // epoch milliseconds

  AttendanceRecord({
    this.id,
    required this.classId,
    required this.studentId,
    required this.dateKey,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'classId': classId,
      'studentId': studentId,
      'dateKey': dateKey,
      'timestamp': timestamp,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      classId: map['classId'] as int,
      studentId: map['studentId'] as int,
      dateKey: map['dateKey'] as String? ?? '',
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }
}

class StudentAttendanceSummary {
  final Student student;
  final int presentCount;
  final int totalSessions;

  StudentAttendanceSummary({
    required this.student,
    required this.presentCount,
    required this.totalSessions,
  });

  double get percentage =>
      totalSessions == 0 ? 0.0 : (presentCount / totalSessions) * 100.0;
}

sealed class MarkResult {}

class MarkSuccess extends MarkResult {
  final Student student;
  final bool alreadyMarkedToday;
  final String method; // 'NFC' or 'Barcode'

  MarkSuccess({
    required this.student,
    required this.alreadyMarkedToday,
    this.method = 'NFC',
  });
}

class MarkUnknownCard extends MarkResult {
  final String rfid;
  MarkUnknownCard(this.rfid);
}

class MarkUnknownBarcode extends MarkResult {
  final String barcode;
  MarkUnknownBarcode(this.barcode);
}
