import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import '../services/nfc_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import 'registration_screen.dart';

enum ScanMode { nfc, barcode }

class ScanLogEntry {
  final String message;
  final Color color;
  final IconData icon;
  final DateTime timestamp;

  ScanLogEntry({
    required this.message,
    required this.color,
    required this.icon,
    required this.timestamp,
  });
}

class ScanScreen extends StatefulWidget {
  final int classId;
  final AttendanceRepository repository;
  final bool nfcAvailable;

  const ScanScreen({
    super.key,
    required this.classId,
    required this.repository,
    required this.nfcAvailable,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  ScanMode _scanMode = ScanMode.nfc;
  SchoolClass? _schoolClass;
  final List<ScanLogEntry> _logs = [];

  // NFC pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Barcode scanner controller
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isTorchOn = false;
  bool _isProcessingBarcode = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!widget.nfcAvailable) {
      _scanMode = ScanMode.barcode;
    }

    _loadClass();
    _initNfc();
  }

  Future<void> _loadClass() async {
    final cls = await widget.repository.getClassById(widget.classId);
    if (mounted) setState(() => _schoolClass = cls);
  }

  void _initNfc() {
    if (widget.nfcAvailable && _scanMode == ScanMode.nfc) {
      NfcService.startSession(
        onDiscovered: (uid) => _handleNfcDiscovered(uid),
        onError: (err) => _addLog(err, AppTheme.warnAmber, Icons.warning_amber),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scannerController.dispose();
    NfcService.stopSession();
    super.dispose();
  }

  void _addLog(String message, Color color, IconData icon) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        ScanLogEntry(
          message: message,
          color: color,
          icon: icon,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _handleNfcDiscovered(String uid) async {
    final result = await widget.repository.scanAndMark(widget.classId, uid);
    if (!mounted) return;

    if (result is MarkSuccess) {
      if (result.alreadyMarkedToday) {
        _addLog(
          "${result.student.name} (${result.student.rollNo}) already marked present today.",
          AppTheme.accentBlue,
          Icons.info_outline,
        );
      } else {
        _addLog(
          "Marked ${result.student.name} (${result.student.rollNo}) present! (NFC)",
          AppTheme.successGreen,
          Icons.check_circle_outline,
        );
      }
    } else if (result is MarkUnknownCard) {
      _addLog(
        "Unknown NFC Card: ${result.rfid}",
        AppTheme.warnAmber,
        Icons.help_outline,
      );
      _showUnregisteredDialog(initialRfid: result.rfid);
    }
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessingBarcode) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.trim().isEmpty) return;

    _isProcessingBarcode = true;
    final cleanCode = barcode.trim();

    final result =
        await widget.repository.scanAndMarkBarcode(widget.classId, cleanCode);
    if (!mounted) {
      _isProcessingBarcode = false;
      return;
    }

    if (result is MarkSuccess) {
      if (result.alreadyMarkedToday) {
        _addLog(
          "${result.student.name} (${result.student.rollNo}) already marked present today.",
          AppTheme.accentBlue,
          Icons.info_outline,
        );
      } else {
        _addLog(
          "Marked ${result.student.name} (${result.student.rollNo}) present! (Barcode)",
          AppTheme.successGreen,
          Icons.check_circle_outline,
        );
      }
    } else if (result is MarkUnknownBarcode) {
      _addLog(
        "Unknown Barcode: ${result.barcode}",
        AppTheme.warnAmber,
        Icons.help_outline,
      );
      _showUnregisteredDialog(initialBarcode: result.barcode);
    }

    // Delay before accepting next barcode to avoid multiple triggers
    await Future.delayed(const Duration(seconds: 2));
    _isProcessingBarcode = false;
  }

  void _showUnregisteredDialog({String? initialRfid, String? initialBarcode}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: AppTheme.accentBlue, size: 24),
            SizedBox(width: 8),
            Text(
              "Identifier Not Linked",
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              initialRfid != null
                  ? "Unregistered NFC Card UID:\n$initialRfid"
                  : "Unregistered Barcode:\n$initialBarcode",
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              "Would you like to register or link this to a student?",
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegistrationScreen(
                    classId: widget.classId,
                    repository: widget.repository,
                    initialRfid: initialRfid,
                    initialBarcode: initialBarcode,
                  ),
                ),
              );
              // Restart NFC session if active
              _initNfc();
            },
            child: const Text("Link Student"),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog(bool isNfc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text(
          isNfc ? "Manual NFC UID Input" : "Manual Barcode / Roll No",
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: isNfc ? "e.g., 04:A2:B3:C4:D5" : "e.g., 2026BCSE001",
            labelText: isNfc ? "RFID / UID" : "Barcode / Roll No",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                if (isNfc) {
                  _handleNfcDiscovered(val);
                } else {
                  _handleBarcodeDetected(
                    BarcodeCapture(barcodes: [Barcode(rawValue: val)]),
                  );
                }
              }
            },
            child: const Text("Simulate Scan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _schoolClass?.name ?? "Attendance Session";

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        "Live Attendance Scanner",
                        style: TextStyle(fontSize: 12, color: AppTheme.accentBlue),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showManualEntryDialog(_scanMode == ScanMode.nfc),
                  tooltip: "Manual Entry / Testing",
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.glassCardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: const Icon(Icons.keyboard, size: 20, color: AppTheme.accentBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mode Selector: NFC vs Barcode
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _scanMode = ScanMode.nfc);
                        _initNfc();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _scanMode == ScanMode.nfc
                              ? AppTheme.accentBlue.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: _scanMode == ScanMode.nfc
                              ? Border.all(color: AppTheme.accentBlue)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.nfc,
                              size: 18,
                              color: _scanMode == ScanMode.nfc
                                  ? AppTheme.accentBlue
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "NFC Mode",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _scanMode == ScanMode.nfc
                                    ? AppTheme.accentBlue
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _scanMode = ScanMode.barcode);
                        NfcService.stopSession();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _scanMode == ScanMode.barcode
                              ? AppTheme.accentBlue.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: _scanMode == ScanMode.barcode
                              ? Border.all(color: AppTheme.accentBlue)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 18,
                              color: _scanMode == ScanMode.barcode
                                  ? AppTheme.accentBlue
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Barcode Camera",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _scanMode == ScanMode.barcode
                                    ? AppTheme.accentBlue
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Scanner Viewport
            if (_scanMode == ScanMode.nfc)
              _buildNfcRadarView()
            else
              _buildBarcodeScannerView(),

            const SizedBox(height: 14),

            // Live Scan Activity Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Activity Feed",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_logs.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _logs.clear()),
                    child: const Text(
                      "Clear",
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Log List
            Expanded(
              child: _logs.isEmpty
                  ? GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          _scanMode == ScanMode.nfc
                              ? "Ready to scan. Tap an NFC card to mark attendance."
                              : "Aim camera at a student ID barcode or QR code.",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: log.color.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(log.icon, color: log.color, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  log.message,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcRadarView() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentBlue.withValues(alpha: 0.25),
                    AppTheme.accentBlue.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(Icons.nfc, size: 50, color: AppTheme.accentBlue),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Hold Student Card Near Device",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "NFC sensor is active and listening for student tags",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showManualEntryDialog(true),
            icon: const Icon(Icons.touch_app, size: 16, color: AppTheme.accentBlue),
            label: const Text(
              "Simulate NFC Tap (Manual UID)",
              style: TextStyle(color: AppTheme.accentBlue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeScannerView() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcodeDetected,
            ),
            // Scanner reticle frame
            Container(
              width: 220,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentBlue, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
              ),
            ),
            // Torch / Camera Switch controls
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      await _scannerController.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? Colors.yellow : Colors.white,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _scannerController.switchCamera(),
                    icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            // Bottom hint
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Align barcode within frame",
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
