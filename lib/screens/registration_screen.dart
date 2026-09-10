import 'package:flutter/material.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import '../services/nfc_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';

class RegistrationScreen extends StatefulWidget {
  final int? classId;
  final AttendanceRepository repository;
  final String? initialRfid;
  final String? initialBarcode;

  const RegistrationScreen({
    super.key,
    this.classId,
    required this.repository,
    this.initialRfid,
    this.initialBarcode,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _rfidController = TextEditingController();
  final _barcodeController = TextEditingController();

  Student? _existingStudent;
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRfid != null) {
      _rfidController.text = widget.initialRfid!;
    }
    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
      // Default rollNo to barcode text since student ID barcodes often equal the roll number
      _rollController.text = widget.initialBarcode!;
    }

    _rollController.addListener(_onRollNoChanged);
    if (_rollController.text.isNotEmpty) {
      _lookupRollNo(_rollController.text);
    }
  }

  @override
  void dispose() {
    _rollController.removeListener(_onRollNoChanged);
    _nameController.dispose();
    _rollController.dispose();
    _rfidController.dispose();
    _barcodeController.dispose();
    NfcService.stopSession();
    super.dispose();
  }

  void _onRollNoChanged() {
    final roll = _rollController.text.trim();
    if (roll.isNotEmpty) {
      _lookupRollNo(roll);
    } else {
      setState(() => _existingStudent = null);
    }
  }

  Future<void> _lookupRollNo(String rollNo) async {
    setState(() => _isSearching = true);
    final student = await widget.repository.findStudentByRollNo(rollNo);
    if (!mounted) return;

    setState(() {
      _existingStudent = student;
      _isSearching = false;
      if (student != null && _nameController.text.trim().isEmpty) {
        _nameController.text = student.name;
      }
    });
  }

  void _startNfcScanForField() {
    NfcService.startSession(
      onDiscovered: (uid) {
        if (mounted) {
          setState(() => _rfidController.text = uid);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Captured NFC UID: $uid"),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppTheme.errorRed),
          );
        }
      },
    );
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final rollNo = _rollController.text.trim();
    final rfid = _rfidController.text.trim().isEmpty ? null : _rfidController.text.trim();
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();

    if (name.isEmpty || rollNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in Student Name and Roll Number."),
          backgroundColor: AppTheme.warnAmber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.classId != null) {
        await widget.repository.registerAndMark(
          classId: widget.classId!,
          name: name,
          rollNo: rollNo,
          rfid: rfid,
          barcode: barcode,
        );
      } else {
        await widget.repository.registerOrUpdateStudent(
          name: name,
          rollNo: rollNo,
          rfid: rfid,
          barcode: barcode,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.classId != null
                  ? "Saved $name and marked present!"
                  : "Saved $name successfully.",
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving student: $e"),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLinking = _existingStudent != null;

    return GlassBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Top Bar
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  isLinking ? "Link Student Identifier" : "Register Student",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  // Existing student found banner
                  if (isLinking)
                    GlassCard(
                      borderColor: AppTheme.accentBlueBright.withValues(alpha: 0.5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_pin_rounded,
                            color: AppTheme.accentBlueBright,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Student Found: ${_existingStudent!.name}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Roll No: ${_existingStudent!.rollNo}. Submitting will link these tags to this student.",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_outlined, color: AppTheme.accentBlue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Student Credentials",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Roll Number Field
                        TextField(
                          controller: _rollController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: "Roll Number *",
                            hintText: "e.g., 2026BCSE042",
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Name Field
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: "Full Name *",
                            hintText: "e.g., Alexander Fleming",
                          ),
                        ),
                      ],
                    ),
                  ),

                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.nfc, color: AppTheme.accentBlue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "NFC & Barcode Identifiers",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // RFID UID
                        TextField(
                          controller: _rfidController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: "NFC Card UID (Optional)",
                            hintText: "e.g., 04:A2:3B:5C:6D:7E",
                            suffixIcon: IconButton(
                              onPressed: _startNfcScanForField,
                              tooltip: "Tap card to read UID",
                              icon: const Icon(Icons.contactless_outlined, color: AppTheme.accentBlue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Barcode
                        TextField(
                          controller: _barcodeController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: "Barcode / QR (Optional)",
                            hintText: "e.g., 2026BCSE042",
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            widget.classId != null
                                ? "Save & Mark Attendance"
                                : (isLinking ? "Link Identifiers" : "Register Student"),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
