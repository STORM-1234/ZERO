import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zerov7/models/device.dart';
import 'package:zerov7/services/esp_ssid_update_tab.dart';
import 'package:zerov7/services/pair_devices_tab.dart';
import 'package:zerov7/services/paired_devices_tab.dart';

class PairDevicesScreen extends StatefulWidget {
  @override
  _PairDevicesScreenState createState() => _PairDevicesScreenState();
}

class _PairDevicesScreenState extends State<PairDevicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // For Paired Devices Tab
  List<Device> pairedDevices = [];
  bool isLoadingPairedDevices = true;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    // If on the web, we only have 1 tab; if on mobile, 3 tabs:
    _tabController = kIsWeb
        ? TabController(length: 1, vsync: this)
        : TabController(length: 3, vsync: this);

    fetchPairedDevices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch paired devices from Firebase
  Future<void> fetchPairedDevices() async {
    try {
      DatabaseReference devicesRef =
      FirebaseDatabase.instance.ref('users/$userId/devices');
      DataSnapshot snapshot = await devicesRef.get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> devicesMap =
        snapshot.value as Map<dynamic, dynamic>;
        List<Device> devices = [];
        devicesMap.forEach((key, value) {
          devices.add(Device.fromMap(value, key));
        });

        setState(() {
          pairedDevices = devices;
          isLoadingPairedDevices = false;
        });
      } else {
        setState(() {
          pairedDevices = [];
          isLoadingPairedDevices = false;
        });
      }
    } catch (e) {
      print("Error fetching paired devices: $e");
      setState(() {
        pairedDevices = [];
        isLoadingPairedDevices = false;
      });
    }
  }

  // Tab 1: ESP SSID Update
  Widget _buildEspSsidUpdateTab() {
    return EspSsidUpdateTab();
  }

  // Tab 2: Pair Devices (QR Code or Manual Entry)
  Widget _buildPairDevicesTab() {
    return PairDevicesTab(
      onDevicePaired: fetchPairedDevices,
    );
  }

  // Tab 3: Paired Devices
  Widget _buildPairedDevicesTab() {
    return PairedDevicesTab(
      onDevicePaired: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build the list of tabs (and tab views) depending on platform
    final tabs = <Tab>[];
    final tabViews = <Widget>[];

    if (kIsWeb) {
      // WEB: only the PairedDevices tab
      tabs.add(const Tab(text: "Devices"));
      tabViews.add(_buildPairedDevicesTab());
    } else {
      // MOBILE: 3 tabs
      tabs.add(const Tab(text: "WiFi"));
      tabs.add(const Tab(text: "Pair"));
      tabs.add(const Tab(text: "Devices"));

      tabViews.add(_buildEspSsidUpdateTab());
      tabViews.add(_buildPairDevicesTab());
      tabViews.add(_buildPairedDevicesTab());
    }

    return Scaffold(
      backgroundColor: Colors.black, // Set background color to black
      appBar: AppBar(
        backgroundColor: Colors.black, // AppBar background to black as well
        title: Row(
          children: const [
            Icon(Icons.wifi, color: Colors.white),
            SizedBox(width: 8), // spacing
            Text("Connect", style: TextStyle(color: Colors.white)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
    );
  }
}
