import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import 'scan_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final int classId;
  final AttendanceRepository repository;
  final bool nfcAvailable;

  const ClassDetailScreen({
    super.key,
    required this.classId,
    required this.repository,
    required this.nfcAvailable,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  SchoolClass? _schoolClass;
  List<StudentAttendanceSummary> _summaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cls = await widget.repository.getClassById(widget.classId);
    final summaries = await widget.repository.getAttendanceSummary(widget.classId);
    setState(() {
      _schoolClass = cls;
      _summaries = summaries;
      _isLoading = false;
    });
  }

  Future<void> _exportCsv() async {
    try {
      final csvString = await widget.repository.exportAttendanceCsv(widget.classId);
      final tempDir = await getTemporaryDirectory();
      final className = (_schoolClass?.name ?? 'Class_${widget.classId}')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${tempDir.path}/${className}_Attendance.csv');
      await file.writeAsString(csvString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Report for ${_schoolClass?.name ?? 'Class'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to export CSV: $e"),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Color _progressColor(double percentage) {
    if (percentage >= 75.0) return AppTheme.successGreen;
    if (percentage >= 50.0) return AppTheme.warnAmber;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final title = _schoolClass?.name ?? "Class";

    return GlassBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_summaries.isNotEmpty)
                  IconButton(
                    onPressed: _exportCsv,
                    tooltip: "Export CSV Report",
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.share, color: AppTheme.accentBlue, size: 18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Hardware warning if NFC is unavailable
            if (!widget.nfcAvailable)
              GlassCard(
                borderColor: AppTheme.warnAmber.withValues(alpha: 0.4),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.warnAmber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "No NFC hardware detected. You can take attendance with Barcode camera scanning or manual UID entry.",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Take Attendance Button
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(
                      classId: widget.classId,
                      repository: widget.repository,
                      nfcAvailable: widget.nfcAvailable,
                    ),
                  ),
                );
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nfc, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "Mark Today's Attendance",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Attendance Summary",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_summaries.isNotEmpty)
                  Text(
                    "${_summaries.length} Students",
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // List of students
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
                  : _summaries.isEmpty
                      ? _buildEmptyRoster()
                      : RefreshIndicator(
                          color: AppTheme.accentBlue,
                          backgroundColor: AppTheme.surfaceDark,
                          onRefresh: _loadData,
                          child: ListView.builder(
                            itemCount: _summaries.length,
                            itemBuilder: (context, index) {
                              final row = _summaries[index];
                              return _buildStudentSummaryCard(row);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRoster() {
    return const GlassCard(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          "No students registered yet.\nTap 'Mark Today's Attendance' above to scan student NFC cards or Barcodes.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildStudentSummaryCard(StudentAttendanceSummary row) {
    final pctColor = _progressColor(row.percentage);

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.student.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Roll no. ${row.student.rollNo}",
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (row.student.rfidUid != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "NFC: ${row.student.rfidUid}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (row.student.barcode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlueBright.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Barcode: ${row.student.barcode}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accentBlueBright,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: row.totalSessions == 0
                        ? 0.0
                        : (row.presentCount / row.totalSessions).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${row.percentage.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: pctColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${row.presentCount}/${row.totalSessions}",
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
