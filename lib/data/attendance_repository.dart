import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'database_helper.dart';
import 'models.dart';

class AttendanceRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<SchoolClass>> getAllClasses() async {
    return await _db.getAllClasses();
  }

  Future<SchoolClass?> getClassById(int classId) async {
    return await _db.getClassById(classId);
  }

  Future<int> createClass(String name) async {
    return await _db.insertClass(SchoolClass(name: name.trim()));
  }

  Future<Student?> findStudentByRollNo(String rollNo) async {
    return await _db.findStudentByRollNo(rollNo.trim());
  }

  Future<Student?> findStudentByRfid(String rfid) async {
    return await _db.findStudentByRfid(rfid.trim());
  }

  Future<Student?> findStudentByBarcode(String barcode) async {
    return await _db.findStudentByBarcode(barcode.trim());
  }

  Future<Student?> findStudentByIdentifier(String identifier) async {
    return await _db.findStudentByIdentifier(identifier.trim());
  }

  /// Registers a new student or updates an existing student with matching rollNo/rfid/barcode.
  /// Handles the vice-versa flow: if a student was registered via Barcode with Roll No,
  /// and later taps a new RFID card, we link that RFID UID to the existing student!
  Future<Student> registerOrUpdateStudent({
    required String name,
    required String rollNo,
    String? rfid,
    String? barcode,
  }) async {
    final cleanRoll = rollNo.trim();
    final cleanName = name.trim();
    final cleanRfid = (rfid != null && rfid.trim().isNotEmpty) ? rfid.trim() : null;
    final cleanBarcode = (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null;

    // Search existing student by roll number first (canonical primary identifier),
    // or by RFID / Barcode.
    Student? existing = await _db.findStudentByRollNo(cleanRoll);
    if (existing == null && cleanRfid != null) {
      existing = await _db.findStudentByRfid(cleanRfid);
    }
    if (existing == null && cleanBarcode != null) {
      existing = await _db.findStudentByBarcode(cleanBarcode);
    }

    if (existing != null) {
      final updated = existing.copyWith(
        name: cleanName.isNotEmpty ? cleanName : existing.name,
        rollNo: cleanRoll.isNotEmpty ? cleanRoll : existing.rollNo,
        rfidUid: cleanRfid ?? existing.rfidUid,
        barcode: cleanBarcode ?? existing.barcode,
      );
      await _db.updateStudent(updated);
      return updated;
    } else {
      final newStudent = Student(
        name: cleanName,
        rollNo: cleanRoll,
        rfidUid: cleanRfid,
        barcode: cleanBarcode,
      );
      final id = await _db.insertStudent(newStudent);
      return newStudent.copyWith(id: id);
    }
  }

  /// NFC Tap Handler: Looks up the scanned RFID.
  /// If the student exists, marks them present for [classId] today (no-op if already marked).
  /// If unknown, returns MarkUnknownCard so UI can route to registration.
  Future<MarkResult> scanAndMark(int classId, String rfid) async {
    final cleanRfid = rfid.trim();
    Student? student = await _db.findStudentByRfid(cleanRfid);
    student ??= await _db.findStudentByRollNo(cleanRfid);

    if (student == null) {
      return MarkUnknownCard(cleanRfid);
    }

    final today = todayKey();
    final alreadyMarked = await _db.isPresentOn(classId, student.id!, today);
    if (!alreadyMarked) {
      await _db.markPresent(
        classId,
        student.id!,
        today,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    return MarkSuccess(
      student: student,
      alreadyMarkedToday: alreadyMarked,
      method: 'NFC',
    );
  }

  /// Barcode / QR Scanner Handler: Looks up scanned barcode or encoded roll number.
  /// If found, associates barcode if missing, and marks attendance.
  /// If unknown, returns MarkUnknownBarcode.
  Future<MarkResult> scanAndMarkBarcode(int classId, String barcode) async {
    final cleanBarcode = barcode.trim();
    Student? student = await _db.findStudentByRollNo(cleanBarcode);
    student ??= await _db.findStudentByBarcode(cleanBarcode);
    student ??= await _db.findStudentByIdentifier(cleanBarcode);

    if (student == null) {
      return MarkUnknownBarcode(cleanBarcode);
    }

    // Link barcode if student was previously saved without it
    if (student.barcode == null || student.barcode!.toLowerCase() != cleanBarcode.toLowerCase()) {
      final updated = student.copyWith(barcode: cleanBarcode);
      await _db.updateStudent(updated);
      student = updated;
    }

    final today = todayKey();
    final alreadyMarked = await _db.isPresentOn(classId, student.id!, today);
    if (!alreadyMarked) {
      await _db.markPresent(
        classId,
        student.id!,
        today,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    return MarkSuccess(
      student: student,
      alreadyMarkedToday: alreadyMarked,
      method: 'Barcode',
    );
  }

  /// Registers or links a student with RFID and/or Barcode, and marks present immediately.
  Future<Student> registerAndMark({
    required int classId,
    required String name,
    required String rollNo,
    String? rfid,
    String? barcode,
  }) async {
    final student = await registerOrUpdateStudent(
      name: name,
      rollNo: rollNo,
      rfid: rfid,
      barcode: barcode,
    );

    final today = todayKey();
    final alreadyMarked = await _db.isPresentOn(classId, student.id!, today);
    if (!alreadyMarked) {
      await _db.markPresent(
        classId,
        student.id!,
        today,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    return student;
  }

  /// Computes student attendance percentages for a class.
  Future<List<StudentAttendanceSummary>> getAttendanceSummary(int classId) async {
    final students = await _db.getAllStudents();
    final sessionDates = await _db.getSessionDates(classId);
    final totalSessions = sessionDates.length;

    final summaries = <StudentAttendanceSummary>[];
    for (final student in students) {
      final presentCount = await _db.getPresentCount(classId, student.id!);
      summaries.add(
        StudentAttendanceSummary(
          student: student,
          presentCount: presentCount,
          totalSessions: totalSessions,
        ),
      );
    }

    summaries.sort((a, b) => b.percentage.compareTo(a.percentage));
    return summaries;
  }

  /// Exports attendance records as a formatted CSV string.
  Future<String> exportAttendanceCsv(int classId) async {
    final students = await _db.getAllStudents();
    final sessionDates = await _db.getSessionDates(classId);

    final rows = <List<dynamic>>[];

    // Header row
    final header = <dynamic>[
      'Student Name',
      'Roll Number',
      'NFC Card UID',
      'Barcode',
      'Total Present',
      'Total Sessions',
      'Attendance %',
      ...sessionDates,
    ];
    rows.add(header);

    for (final s in students) {
      final presentCount = await _db.getPresentCount(classId, s.id!);
      final totalSessions = sessionDates.length;
      final pct = totalSessions == 0
          ? '0%'
          : '${((presentCount / totalSessions) * 100).toStringAsFixed(1)}%';

      final row = <dynamic>[
        s.name,
        s.rollNo,
        s.rfidUid ?? '',
        s.barcode ?? '',
        presentCount,
        totalSessions,
        pct,
      ];

      for (final date in sessionDates) {
        final wasPresent = await _db.isPresentOn(classId, s.id!, date);
        row.add(wasPresent ? 'P' : 'A');
      }

      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  String todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());
}
