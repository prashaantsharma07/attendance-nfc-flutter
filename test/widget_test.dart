import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_nfc/data/models.dart';

void main() {
  group('Attendance Models Unit Tests', () {
    test('SchoolClass model serialization', () {
      final cls = SchoolClass(id: 1, name: 'Computer Science 101');
      final map = cls.toMap();
      expect(map['name'], 'Computer Science 101');
      expect(map['id'], 1);

      final restored = SchoolClass.fromMap(map);
      expect(restored.id, 1);
      expect(restored.name, 'Computer Science 101');
    });

    test('Student model creation, copyWith, and serialization', () {
      final student = Student(
        id: 42,
        name: 'Jane Doe',
        rollNo: '2026BCSE042',
        rfidUid: '04:A2:3B:5C',
        barcode: '2026BCSE042',
      );

      expect(student.name, 'Jane Doe');
      expect(student.rollNo, '2026BCSE042');
      expect(student.rfidUid, '04:A2:3B:5C');

      final updated = student.copyWith(name: 'Jane Smith');
      expect(updated.name, 'Jane Smith');
      expect(updated.rollNo, '2026BCSE042');

      final map = updated.toMap();
      final fromMap = Student.fromMap(map);
      expect(fromMap.name, 'Jane Smith');
      expect(fromMap.rollNo, '2026BCSE042');
    });

    test('StudentAttendanceSummary calculates percentage correctly', () {
      final student = Student(name: 'Alice', rollNo: '101');

      final summaryZero = StudentAttendanceSummary(
        student: student,
        presentCount: 0,
        totalSessions: 0,
      );
      expect(summaryZero.percentage, 0.0);

      final summary75 = StudentAttendanceSummary(
        student: student,
        presentCount: 15,
        totalSessions: 20,
      );
      expect(summary75.percentage, 75.0);

      final summary100 = StudentAttendanceSummary(
        student: student,
        presentCount: 10,
        totalSessions: 10,
      );
      expect(summary100.percentage, 100.0);
    });

    test('AttendanceRecord serialization', () {
      final record = AttendanceRecord(
        id: 1,
        classId: 10,
        studentId: 25,
        dateKey: '2026-09-10',
        timestamp: 1725960000000,
      );

      final map = record.toMap();
      expect(map['classId'], 10);
      expect(map['studentId'], 25);
      expect(map['dateKey'], '2026-09-10');

      final restored = AttendanceRecord.fromMap(map);
      expect(restored.classId, 10);
      expect(restored.studentId, 25);
      expect(restored.dateKey, '2026-09-10');
    });
  });
}
