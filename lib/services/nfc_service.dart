import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint("NfcService.isAvailable check error: $e");
      return false;
    }
  }

  static void startSession({
    required Function(String uid) onDiscovered,
    required Function(String error) onError,
  }) {
    NfcManager.instance.startSession(
      alertMessage: "Hold your student NFC card near the device to mark attendance.",
      onDiscovered: (NfcTag tag) async {
        try {
          String? identifier;
          final data = tag.data;

          // Android tag types
          if (data.containsKey('nfca') && data['nfca'] != null) {
            final nfca = data['nfca'];
            if (nfca['identifier'] != null) {
              identifier = _bytesToHex(nfca['identifier']);
            }
          } else if (data.containsKey('nfcb') && data['nfcb'] != null) {
            final nfcb = data['nfcb'];
            if (nfcb['identifier'] != null) {
              identifier = _bytesToHex(nfcb['identifier']);
            }
          } else if (data.containsKey('mifare') && data['mifare'] != null) {
            final mifare = data['mifare'];
            if (mifare['identifier'] != null) {
              identifier = _bytesToHex(mifare['identifier']);
            }
          } else if (data.containsKey('iso7816') && data['iso7816'] != null) {
            final iso = data['iso7816'];
            if (iso['identifier'] != null) {
              identifier = _bytesToHex(iso['identifier']);
            }
          } else if (data.containsKey('isodep') && data['isodep'] != null) {
            final isodep = data['isodep'];
            if (isodep['identifier'] != null) {
              identifier = _bytesToHex(isodep['identifier']);
            }
          }

          // iOS CoreNFC tag types (MiFare, ISO7816, ISO15693, FeliCa)
          if (identifier == null) {
            if (data.containsKey('mifare') && data['mifare'] != null) {
              final id = data['mifare']['identifier'];
              if (id != null) identifier = _bytesToHex(id);
            } else if (data.containsKey('iso7816') && data['iso7816'] != null) {
              final id = data['iso7816']['identifier'];
              if (id != null) identifier = _bytesToHex(id);
            } else if (data.containsKey('iso15693') && data['iso15693'] != null) {
              final id = data['iso15693']['identifier'];
              if (id != null) identifier = _bytesToHex(id);
            }
          }

          // Fallback recursive lookup for 'identifier'
          if (identifier == null) {
            for (final entry in data.entries) {
              if (entry.value is Map) {
                final m = entry.value as Map;
                if (m.containsKey('identifier') && m['identifier'] != null) {
                  identifier = _bytesToHex(m['identifier']);
                  break;
                }
              }
            }
          }

          if (identifier != null && identifier.isNotEmpty) {
            onDiscovered(identifier);
          } else {
            onError("Scanned tag does not expose an identifier.");
          }
        } catch (e) {
          onError("Failed processing NFC card: $e");
        }
      },
    );
  }

  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  static String _bytesToHex(dynamic bytes) {
    if (bytes is List) {
      return bytes
          .map((b) => (b as int).toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
    }
    return bytes.toString().toUpperCase();
  }
}
