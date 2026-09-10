import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'attendance.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE classes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rfidUid TEXT UNIQUE,
            barcode TEXT UNIQUE,
            name TEXT NOT NULL,
            rollNo TEXT UNIQUE NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            classId INTEGER NOT NULL,
            studentId INTEGER NOT NULL,
            dateKey TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(classId, studentId, dateKey)
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_attendance_lookup ON attendance_records (classId, dateKey)',
        );
      },
    );
  }

  // Classes
  Future<int> insertClass(SchoolClass schoolClass) async {
    final db = await database;
    return await db.insert('classes', schoolClass.toMap());
  }

  Future<List<SchoolClass>> getAllClasses() async {
    final db = await database;
    final maps = await db.query('classes', orderBy: 'id DESC');
    return maps.map((e) => SchoolClass.fromMap(e)).toList();
  }

  Future<SchoolClass?> getClassById(int id) async {
    final db = await database;
    final maps = await db.query('classes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return SchoolClass.fromMap(maps.first);
    }
    return null;
  }

  // Students
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final maps = await db.query('students', orderBy: 'name ASC');
    return maps.map((e) => Student.fromMap(e)).toList();
  }

  Future<Student?> findStudentByRollNo(String rollNo) async {
    final db = await database;
    final clean = rollNo.trim();
    final maps = await db.query(
      'students',
      where: 'LOWER(rollNo) = LOWER(?)',
      whereArgs: [clean],
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  Future<Student?> findStudentByRfid(String rfid) async {
    final db = await database;
    final clean = rfid.trim();
    final maps = await db.query(
      'students',
      where: 'LOWER(rfidUid) = LOWER(?)',
      whereArgs: [clean],
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  Future<Student?> findStudentByBarcode(String barcode) async {
    final db = await database;
    final clean = barcode.trim();
    final maps = await db.query(
      'students',
      where: 'LOWER(barcode) = LOWER(?)',
      whereArgs: [clean],
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  Future<Student?> findStudentByIdentifier(String idStr) async {
    final db = await database;
    final clean = idStr.trim();
    final maps = await db.query(
      'students',
      where: 'LOWER(rfidUid) = LOWER(?) OR LOWER(barcode) = LOWER(?) OR LOWER(rollNo) = LOWER(?)',
      whereArgs: [clean, clean, clean],
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  // Attendance Records
  Future<int> markPresent(int classId, int studentId, String dateKey, int timestamp) async {
    final db = await database;
    return await db.insert(
      'attendance_records',
      {
        'classId': classId,
        'studentId': studentId,
        'dateKey': dateKey,
        'timestamp': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> isPresentOn(int classId, int studentId, String dateKey) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM attendance_records WHERE classId = ? AND studentId = ? AND dateKey = ?',
      [classId, studentId, dateKey],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  Future<int> getPresentCount(int classId, int studentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM attendance_records WHERE classId = ? AND studentId = ?',
      [classId, studentId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getSessionDates(int classId) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT dateKey FROM attendance_records WHERE classId = ? ORDER BY dateKey ASC',
      [classId],
    );
    return maps.map((e) => e['dateKey'] as String).toList();
  }

  Future<List<AttendanceRecord>> getRecordsForClass(int classId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'classId = ?',
      whereArgs: [classId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => AttendanceRecord.fromMap(e)).toList();
  }
}
