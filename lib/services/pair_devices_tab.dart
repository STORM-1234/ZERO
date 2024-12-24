import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zerov7/services/qr_scanner_screen.dart';
import 'package:zerov7/restart_widget.dart';

class PairDevicesTab extends StatefulWidget {
  final VoidCallback onDevicePaired;

  const PairDevicesTab({Key? key, required this.onDevicePaired})
      : super(key: key);

  @override
  _PairDevicesTabState createState() => _PairDevicesTabState();
}

class _PairDevicesTabState extends State<PairDevicesTab> {
  final TextEditingController _deviceIdController = TextEditingController();
  bool isPairing = false;
  String? _errorMessage;

  Future<void> _pairDeviceManually() async {
    String deviceId = _deviceIdController.text.trim();

    // Allow only specific device IDs
    if (deviceId != 'zero_prototype008' && deviceId != 'zero_prototype009') {
      setState(() {
        _errorMessage = "Invalid device ID.";
      });
      return;
    }

    setState(() {
      isPairing = true;
      _errorMessage = null;
    });

    try {
      await _addDeviceToFirebase(deviceId);

      setState(() {
        _errorMessage = null;
      });

      widget.onDevicePaired();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Device paired successfully.")),
      );

      RestartWidget.restartApp(context);
    } catch (e) {
      print("Error pairing device: $e");
      setState(() {
        _errorMessage = "Failed to pair device. Please try again.";
      });
    } finally {
      setState(() {
        isPairing = false;
      });
    }
  }

  Future<void> _addDeviceToFirebase(String deviceId) async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final String deviceName =
        "Zero Module ${deviceId.substring(deviceId.length - 3)}";
    final String addedAt = DateTime.now().toIso8601String();
    final String email = FirebaseAuth.instance.currentUser!.email ?? "";

    DatabaseReference deviceRef =
    FirebaseDatabase.instance.ref('users/$userId/devices/$deviceId');

    await deviceRef.set({
      'name': deviceName,
      'added_at': addedAt,
      'email': email,
    });

    print("Device added to Firebase.");
  }

  void _onDetect(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) return;

    final String? scannedDeviceId = capture.barcodes.first.rawValue;
    if (scannedDeviceId != null && scannedDeviceId.isNotEmpty) {
      setState(() {
        _deviceIdController.text = scannedDeviceId;
      });

      await _pairDeviceManually(); // Pair the device manually

      RestartWidget.restartApp(context); // Restart the app after pairing
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              kToolbarHeight -
              MediaQuery.of(context).padding.top,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text("Scan QR Code"),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => QRScannerScreen(
                          onDetect: _onDetect,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("OR",
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                  ],
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _deviceIdController,
                  decoration: InputDecoration(
                    labelText: "Enter Device ID",
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: Colors.cyanAccent, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 10),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 20),
                isPairing
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _pairDeviceManually,
                  child: Text("Pair Device"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
