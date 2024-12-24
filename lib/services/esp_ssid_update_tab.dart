import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class EspSsidUpdateTab extends StatefulWidget {
  @override
  _EspSsidUpdateTabState createState() => _EspSsidUpdateTabState();
}

class _EspSsidUpdateTabState extends State<EspSsidUpdateTab> {
  List<WiFiAccessPoint> wifiNetworks = [];
  bool isLoading = false;
  String? _successMessage;

  // Fetch available Wi-Fi networks
  Future<void> fetchWiFiNetworks() async {
    setState(() {
      isLoading = true;
    });

    try {
      final canStartScan = await WiFiScan.instance.canStartScan();

      if (canStartScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future.delayed(Duration(seconds: 2));
        List<WiFiAccessPoint> networks =
        await WiFiScan.instance.getScannedResults();

        setState(() {
          wifiNetworks = networks;
        });
      } else {
        print("Cannot start Wi-Fi scan. Reason: $canStartScan");
      }
    } catch (e) {
      print("Error fetching Wi-Fi networks: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchWiFiNetworks();
  }

  @override
  Widget build(BuildContext context) {
    bool isESPAvailable =
    wifiNetworks.any((e) => e.ssid == "ZERO");

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('asset/backgrounds/pair/pair_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Foreground Content
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              padding: EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.cyanAccent,
                  width: 0.5,
                ),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.68,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Tap The Highlighted Network To Open ",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: Colors.white.withOpacity(0.2),
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    // Wi-Fi List
                    SizedBox(
                      height: 230,
                      child: RefreshIndicator(
                        onRefresh: fetchWiFiNetworks,
                        child: ListView.builder(
                          padding: EdgeInsets.all(8.0),
                          itemCount:
                          isESPAvailable ? wifiNetworks.length : 1,
                          itemBuilder: (context, index) {
                            if (!isESPAvailable) {
                              return _noWiFiFoundMessage();
                            }

                            final network = wifiNetworks[index];
                            bool isESPNetwork =
                                network.ssid == "ZERO";

                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 8.0),
                              child: GestureDetector(
                                onTap:
                                isESPNetwork ? _openWiFiSettings : null,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isESPNetwork
                                          ? Colors.cyanAccent
                                          : Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.wifi,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          network.ssid ?? "Unknown",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display when ESP network is not found
  Widget _noWiFiFoundMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.signal_wifi_off,
              color: Colors.redAccent,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Zero module not found",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to open Wi-Fi settings on Android
  void _openWiFiSettings() async {
    if (Platform.isAndroid) {
      try {
        // Open Wi-Fi settings
        final intent = AndroidIntent(
          action: 'android.settings.WIFI_SETTINGS',
        );
        await intent.launch();

        // Wait for the user to return to the app
        await Future.delayed(Duration(seconds: 5));

        if (!mounted) return; // Ensure the widget is still in the tree

        // Fetch the current connected Wi-Fi SSID
        final networkInfo = NetworkInfo();
        String? currentSSID = await networkInfo.getWifiName();

        // Show the SSID and password dialog directly
        _showSSIDAndPasswordDialog();
      } catch (e) {
        print("Could not open Wi-Fi settings: $e");
      }
    } else {
      print("This feature is only supported on Android devices.");
    }
  }

  // Function to display SSID and Password input dialog
  void _showSSIDAndPasswordDialog() {
    TextEditingController ssidController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    bool isPasswordVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.cyanAccent,
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enter New Wi-Fi Details",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 16),
                _buildTextField(
                  "SSID",
                  ssidController,
                  isPasswordVisible: false,
                  onVisibilityToggle: (_) {},
                ),
                SizedBox(height: 16),
                _buildTextField(
                  "Password",
                  passwordController,
                  isPasswordVisible: isPasswordVisible,
                  onVisibilityToggle: (value) {
                    setState(() {
                      isPasswordVisible = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        // Capture user input (SSID and Password)
                        String newSSID = ssidController.text.trim();
                        String newPassword = passwordController.text.trim();

                        Navigator.pop(context);
                        await _updateWiFiCredentials(newSSID, newPassword);
                        setState(() {
                          // Reset the UI
                          _successMessage =
                          "Wi-Fi credentials updated successfully.";
                        });


                      },
                      child: Text("Submit"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTextField(
      String label,
      TextEditingController controller, {
        required bool isPasswordVisible,
        required ValueChanged<bool> onVisibilityToggle,
      }) {
    return TextField(
      controller: controller,
      obscureText: label == "Password" && !isPasswordVisible,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(1),
        contentPadding:
        EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Colors.cyanAccent),
        ),
        suffixIcon: label == "Password"
            ? IconButton(
          icon: Icon(
            isPasswordVisible
                ? Icons.visibility
                : Icons.visibility_off,
            color: Colors.white54,
          ),
          onPressed: () {
            onVisibilityToggle(!isPasswordVisible);
          },
        )
            : null,
      ),
      style: TextStyle(color: Colors.white),
    );
  }

  // Function to update Wi-Fi credentials on the ESP device
  Future<void> _updateWiFiCredentials(
      String ssid, String password) async {
    const String espUrl = "http://192.168.4.1/update";
    try {
      await http.post(
        Uri.parse(espUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"ssid": ssid, "password": password},
      );
      // The result is ignored here since success is always assumed.
      print("Wi-Fi credentials submitted.");
    } catch (e) {
      print("Error updating Wi-Fi credentials: $e");
    }
  }


}
