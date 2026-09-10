import 'package:flutter/material.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import 'class_detail_screen.dart';
import 'scan_screen.dart';

class ClassListScreen extends StatefulWidget {
  final AttendanceRepository repository;
  final bool nfcAvailable;

  const ClassListScreen({
    super.key,
    required this.repository,
    required this.nfcAvailable,
  });

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  List<SchoolClass> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    final classes = await widget.repository.getAllClasses();
    setState(() {
      _classes = classes;
      _isLoading = false;
    });
  }

  void _showAddClassDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text(
          "New Class",
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: "e.g., Data Structures & Algorithms",
            labelText: "Class Name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await widget.repository.createClass(name);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  _loadClasses();
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AttendanceNFC",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      widget.nfcAvailable
                          ? "NFC Ready • Tap card or scan barcode"
                          : "NFC Offline • Barcode mode available",
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.nfcAvailable
                            ? AppTheme.accentBlue
                            : AppTheme.warnAmber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _showAddClassDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.add, color: AppTheme.accentBlue, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Class list count or title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Your Classes (${_classes.length})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddClassDialog,
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.accentBlue),
                  label: const Text(
                    "Add Class",
                    style: TextStyle(color: AppTheme.accentBlue, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
                  : _classes.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppTheme.accentBlue,
                          backgroundColor: AppTheme.surfaceDark,
                          onRefresh: _loadClasses,
                          child: ListView.builder(
                            itemCount: _classes.length,
                            itemBuilder: (context, index) {
                              final cls = _classes[index];
                              return _buildClassCard(cls);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.class_outlined, size: 48, color: AppTheme.accentBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Classes Created Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create your first class to begin taking attendance using student NFC ID cards or Barcodes.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showAddClassDialog,
              icon: const Icon(Icons.add),
              label: const Text("Create Class"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(SchoolClass cls) {
    return GlassCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassDetailScreen(
              classId: cls.id!,
              repository: widget.repository,
              nfcAvailable: widget.nfcAvailable,
            ),
          ),
        );
        _loadClasses();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cls.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanScreen(
                          classId: cls.id!,
                          repository: widget.repository,
                          nfcAvailable: widget.nfcAvailable,
                        ),
                      ),
                    );
                    _loadClasses();
                  },
                  icon: const Icon(Icons.nfc, size: 18, color: AppTheme.accentBlue),
                  label: const Text(
                    "Take Attendance",
                    style: TextStyle(color: AppTheme.accentBlue, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
