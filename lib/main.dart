import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/attendance_repository.dart';
import 'screens/class_list_screen.dart';
import 'services/nfc_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark status bar / navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final nfcAvailable = await NfcService.isAvailable();
  final repository = AttendanceRepository();

  runApp(AttendanceNfcApp(
    repository: repository,
    nfcAvailable: nfcAvailable,
  ));
}

class AttendanceNfcApp extends StatelessWidget {
  final AttendanceRepository repository;
  final bool nfcAvailable;

  const AttendanceNfcApp({
    super.key,
    required this.repository,
    required this.nfcAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendanceNFC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ClassListScreen(
        repository: repository,
        nfcAvailable: nfcAvailable,
      ),
    );
  }
}
