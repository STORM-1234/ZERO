import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:zerov7/models/device.dart';
import 'package:zerov7/screens/pair_devices_screen.dart';
import 'package:zerov7/screens/records_charts_screen.dart';
import 'package:zerov7/screens/user_screen.dart';
import 'package:zerov7/services/chat_screen.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:zerov7/screens/cards/animation/hoverable_card.dart';
import 'package:zerov7/screens/admin_page.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;
  bool _showChat = false;
  bool isAdmin = false;

  final String userId = FirebaseAuth.instance.currentUser!.uid;

  List<Device> pairedDevices = [];
  bool isLoadingDevices = true;

  Device? selectedDevice;

  double temperature = 0;
  double humidity = 0;
  double airQuality = 0;
  Map<String, double> gasLevels = {};
  String locationInfo = "Fetching location...";

  DatabaseReference? sensorRef;
  StreamSubscription<DatabaseEvent>? sensorSubscription;

  Timer? _locationTimer;

  // Replace with your actual Google Geocoding API key
  static const String _googleGeocodingApiKey = 'Your Api Key';

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _fetchPairedDevices();
    _fetchLocation();
    // Periodically fetch location every 60 minutes
    _locationTimer = Timer.periodic(const Duration(minutes: 60), (Timer t) => _fetchLocation());
  }

  @override
  void dispose() {
    sensorSubscription?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  // Check if user is admin from Firestore
  Future<void> _checkAdmin() async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        setState(() {
          isAdmin = userDoc.get('role') == 'admin';
        });
      } else {
        setState(() {
          isAdmin = false;
        });
      }
    } catch (e) {
      print("Error checking admin status: $e");
      setState(() {
        isAdmin = false;
      });
    }
  }

  // Fetch devices from Realtime Database
  Future<void> _fetchPairedDevices() async {
    try {
      DatabaseReference devicesRef =
      FirebaseDatabase.instance.ref('users/$userId/devices');
      DataSnapshot snapshot = await devicesRef.get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> devicesMap = snapshot.value as Map<dynamic, dynamic>;
        List<Device> devices = [];
        Device? currentlySelected;

        devicesMap.forEach((key, value) {
          Device dev = Device.fromMap(value, key);
          devices.add(dev);
          // If the device is toggled ON in DB, mark it as selected
          if (dev.selected) {
            currentlySelected = dev;
          }
        });

        setState(() {
          pairedDevices = devices;
          isLoadingDevices = false;
          if (currentlySelected != null) {
            selectedDevice = currentlySelected;
            _setupSensorListener(selectedDevice!.deviceId);
          } else if (devices.isNotEmpty) {
            // If no device is selected in DB, you could pick the first or do nothing
            selectedDevice = null;
          }
        });
      } else {
        setState(() {
          pairedDevices = [];
          isLoadingDevices = false;
          selectedDevice = null;
        });
      }
    } catch (e) {
      print("Error fetching paired devices: $e");
      setState(() {
        pairedDevices = [];
        isLoadingDevices = false;
        selectedDevice = null;
      });
    }
  }

  // Listen to sensor data of the selected device
  void _setupSensorListener(String deviceId) {
    sensorSubscription?.cancel(); // Cancel previous subscription if any
    sensorRef = FirebaseDatabase.instance.ref('$deviceId/sensor');

    sensorSubscription = sensorRef!.onValue.listen((event) {
      if (!mounted) return; // Safeguard if widget disposed
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        setState(() {
          temperature = _toDoubleSafe(data['temperature']);
          humidity = _toDoubleSafe(data['humidity']);
          airQuality = _toDoubleSafe(data['airQualityIndex']);
          gasLevels = {
            'CO2': _toDoubleSafe(data['CO2']),
            'NH3': _toDoubleSafe(data['NH3']),
            'Benzene': _toDoubleSafe(data['Benzene']),
            'Sulfur': _toDoubleSafe(data['Sulfur']),
          };
        });
      }
    }, onError: (error) {
      print("Error listening to sensor data: $error");
    });
  }

  // Safely convert dynamic to double
  double _toDoubleSafe(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  // Fetch user's location
  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print("Location services enabled: $serviceEnabled");
      if (!serviceEnabled) {
        setState(() {
          locationInfo = "Location services are disabled.";
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      print("Location permission status: $permission");
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print("Requested location permission: $permission");
        if (permission == LocationPermission.denied) {
          setState(() {
            locationInfo = "Location permissions are denied.";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          locationInfo = "Location permissions are permanently denied.";
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("Fetched position: ${position.latitude}, ${position.longitude}");

      // Reverse geocode differently on web vs mobile
      if (kIsWeb) {
        String? address =
        await _reverseGeocodeWeb(position.latitude, position.longitude);
        if (address != null) {
          setState(() {
            locationInfo = address;
          });
        } else {
          setState(() {
            locationInfo = "Unable to determine the location.";
          });
        }
      } else {
        final placemarks = await geo.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        print("Number of placemarks found: ${placemarks.length}");

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          print("Placemarks first entry: $place");
          setState(() {
            String subLocality = place.subLocality ?? "";
            String locality = place.locality ?? "";
            String country = place.country ?? "Unknown country";

            if (subLocality.isNotEmpty && locality.isNotEmpty) {
              locationInfo = "$subLocality, $locality, $country";
            } else if (locality.isNotEmpty) {
              locationInfo = "$locality, $country";
            } else {
              locationInfo = "$country";
            }
          });
        } else {
          setState(() {
            locationInfo = "Unable to determine the location.";
          });
          print("Reverse geocoding returned an empty placemarks list.");
        }
      }
    } catch (e) {
      setState(() {
        locationInfo = "Error fetching location.";
      });
      print("Error fetching location: $e");
    }
  }

  // Reverse geocode for web
  Future<String?> _reverseGeocodeWeb(double latitude, double longitude) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude&key=$_googleGeocodingApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      print("Reverse Geocoding API Request URL: $url");
      print("Reverse Geocoding API Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print("Reverse Geocoding API Response Data: $data");

        if (data['status'] == 'OK') {
          if (data['results'] != null && data['results'].isNotEmpty) {
            for (var result in data['results']) {
              // Skip plus code addresses
              if (!result['formatted_address'].contains('+')) {
                final String formattedAddress = result['formatted_address'];
                print("Formatted Address (no plus code): $formattedAddress");

                List<String> addressParts = formattedAddress
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
                if (addressParts.length >= 3) {
                  String desiredAddress =
                      "${addressParts[addressParts.length - 3]}, "
                      "${addressParts[addressParts.length - 2]}, "
                      "${addressParts.last}";
                  print("Desired Address: $desiredAddress");
                  return desiredAddress;
                } else if (addressParts.length >= 2) {
                  String desiredAddress =
                      "${addressParts[addressParts.length - 2]}, "
                      "${addressParts.last}";
                  print("Desired Address: $desiredAddress");
                  return desiredAddress;
                } else {
                  return formattedAddress;
                }
              }
            }
            // Fallback if we never found a plus-code-free address
            final firstResult = data['results'][0];
            final List<dynamic> addressComponents =
            firstResult['address_components'];

            List<String> addressParts = [];
            for (var component in addressComponents) {
              List<dynamic> types = component['types'];
              if (!types.contains('plus_code')) {
                addressParts.add(component['long_name']);
              }
            }

            String cleanedAddress = addressParts.join(', ');
            print("Cleaned Formatted Address: $cleanedAddress");

            List<String> cleanedParts =
            cleanedAddress.split(',').map((e) => e.trim()).toList();
            if (cleanedParts.length >= 3) {
              String desiredAddress =
                  "${cleanedParts[cleanedParts.length - 3]}, "
                  "${cleanedParts[cleanedParts.length - 2]}, "
                  "${cleanedParts.last}";
              print("Desired Address: $desiredAddress");
              return desiredAddress;
            } else if (cleanedParts.length >= 2) {
              String desiredAddress =
                  "${cleanedParts[cleanedParts.length - 2]}, "
                  "${cleanedParts.last}";
              print("Desired Address: $desiredAddress");
              return desiredAddress;
            } else {
              return cleanedAddress.isNotEmpty
                  ? cleanedAddress
                  : "Unknown Location";
            }
          } else {
            print("No results found in geocoding response.");
            return "Location data unavailable.";
          }
        } else {
          String errorMessage = data['error_message'] ?? 'No error message provided.';
          print("Geocoding API error: ${data['status']} - $errorMessage");
          return "Error: ${data['status']}";
        }
      } else {
        print("Geocoding API HTTP error: ${response.statusCode} "
            "${response.reasonPhrase}");
        return "HTTP Error: ${response.statusCode}";
      }
    } catch (e) {
      print("Exception during reverse geocoding: $e");
      return "Error fetching location.";
    }
  }


  // Helper for index box in air quality gauge
  Widget _buildIndexBox(String label, String range, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            range,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Air quality gauge
  Widget _buildAirQualityGauge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Air Quality Index",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  startAngle: 180,
                  endAngle: 0,
                  minimum: 0,
                  maximum: 500,
                  showLabels: true,
                  showTicks: false,
                  axisLineStyle: const AxisLineStyle(
                    thickness: 30,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 0,
                      endValue: 50,
                      color: Colors.green,
                      startWidth: 30,
                      endWidth: 30,
                    ),
                    GaugeRange(
                      startValue: 50,
                      endValue: 100,
                      color: Colors.yellow,
                      startWidth: 30,
                      endWidth: 30,
                    ),
                    GaugeRange(
                      startValue: 100,
                      endValue: 150,
                      color: Colors.orange,
                      startWidth: 30,
                      endWidth: 30,
                    ),
                    GaugeRange(
                      startValue: 150,
                      endValue: 200,
                      color: Colors.red,
                      startWidth: 30,
                      endWidth: 30,
                    ),
                    GaugeRange(
                      startValue: 200,
                      endValue: 300,
                      color: Colors.purple,
                      startWidth: 30,
                      endWidth: 30,
                    ),
                    GaugeRange(
                      startValue: 300,
                      endValue: 500,
                      color: Colors.deepPurple,
                      startWidth: 30,
                      endWidth: 30,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: airQuality,
                      needleColor: Colors.blue,
                      needleLength: 0.8,
                      needleStartWidth: 0.5,
                      needleEndWidth: 5,
                      knobStyle: const KnobStyle(
                        color: Colors.white,
                        sizeUnit: GaugeSizeUnit.factor,
                        knobRadius: 0.07,
                      ),
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Text(
                        airQuality.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      angle: 90,
                      positionFactor: 0.2,
                    ),
                  ],
                ),
              ],
            ),
            // Legend box
            Positioned(
              top: 250,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyan, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIndexBox("Good", "0-50", Colors.green),
                    const SizedBox(height: 5),
                    _buildIndexBox("Moderate", "51-100", Colors.yellow),
                    const SizedBox(height: 5),
                    _buildIndexBox("Slightly Unhealthy", "101-150", Colors.orange),
                    const SizedBox(height: 5),
                    _buildIndexBox("Unhealthy", "151-200", Colors.red),
                    const SizedBox(height: 5),
                    _buildIndexBox("Very Unhealthy", "201-300", Colors.purple),
                    const SizedBox(height: 5),
                    _buildIndexBox("Hazardous", "301-500", Colors.deepPurple),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reusable card with title/subtitle
  Widget _buildCardWithTitle(String title, String subtitle, IconData icon) {
    return HoverableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // Reusable card that shows only a subtitle widget
  Widget _buildCardWithoutTitle(Widget subtitle, IconData icon) {
    return HoverableCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue, size: 40),
          const SizedBox(height: 10),
          subtitle,
        ],
      ),
    );
  }

  // Web version of temperature
  Widget _buildWebTemperatureCard() {
    double temperatureInFahrenheit = (temperature * 9 / 5) + 32;

    return _buildCardWithTitle(
      "Temperature",
      "${temperature.toStringAsFixed(1)}°C / ${temperatureInFahrenheit.toStringAsFixed(1)}°F",
      Icons.thermostat_outlined,
    );
  }

  // Web version of humidity
  Widget _buildWebHumidityCard() {
    return _buildCardWithTitle(
      "Humidity",
      "${humidity.toStringAsFixed(1)}%",
      Icons.water_drop_outlined,
    );
  }

  // Web version of gas
  Widget _buildWebGasLevelCard(String gasName, double level) {
    return _buildCardWithTitle(
      "$gasName Levels",
      "${level.toStringAsFixed(2)} ppm",
      Icons.cloud_outlined,
    );
  }

  // Android (mobile) Home layout
  Widget _buildAndroidHomeContent() {
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());
    String currentDate = DateFormat('EEEE, dd MMMM').format(DateTime.now());

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isLoadingDevices
            ? const Center(child: CircularProgressIndicator())
            : pairedDevices.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, color: Colors.yellow, size: 80),
              const SizedBox(height: 20),
              const Text(
                "No devices paired.\nPlease pair your Zero Module to view data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // jump to devices tab
                    _selectedIndex = _getDevicesTabIndex();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Pair Device"),
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  locationInfo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _buildCardWithoutTitle(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      currentDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      currentTime,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Icons.calendar_today,
              ),
            ),
            const SizedBox(height: 30),
            Center(child: _buildAirQualityGauge()),
            const SizedBox(height: 280),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 170,
                  height: 200,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _buildCardWithTitle(
                      "Temperature",
                      "${temperature.toStringAsFixed(1)}°C / ${(temperature * 9 / 5 + 32).toStringAsFixed(1)}°F",
                      Icons.thermostat_outlined,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  height: 200,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _buildCardWithTitle(
                      "Humidity",
                      "${humidity.toStringAsFixed(1)}%",
                      Icons.water_drop_outlined,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Gas Levels",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: gasLevels.entries.map((entry) {
                return _buildCardWithTitle(
                  "${entry.key}",
                  "${entry.value.toStringAsFixed(2)} ppm",
                  Icons.cloud_outlined,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Web layout
  Widget _buildWebHomeContent() {
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());
    String currentDate = DateFormat('EEEE, dd MMMM').format(DateTime.now());

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 100.0, vertical: 40.0),
            child: isLoadingDevices
                ? const Center(child: CircularProgressIndicator())
                : pairedDevices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning,
                      color: Colors.yellow, size: 100),
                  const SizedBox(height: 30),
                  const Text(
                    "No devices paired.\nPlease pair your Zero Module to view data.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 30),
                  // If you want a "Pair Device" button on web
                  ElevatedButton(
                    onPressed: () {
                      _onItemTapped(_getDevicesTabIndex());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Pair Device"),
                  ),
                ],
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      locationInfo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _buildCardWithoutTitle(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          currentDate,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          currentTime,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    Icons.calendar_today,
                  ),
                ),
                const SizedBox(height: 30),
                _buildAirQualityGauge(),
                const SizedBox(height: 280),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 3,
                  ),
                  itemCount: gasLevels.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildWebTemperatureCard();
                    } else if (index == 1) {
                      return _buildWebHumidityCard();
                    } else {
                      final gasEntry =
                      gasLevels.entries.elementAt(index - 2);
                      return _buildWebGasLevelCard(
                        gasEntry.key,
                        gasEntry.value,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // On bottom nav tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Return the index of the Devices/Connect tab in your bottom nav
  int _getDevicesTabIndex() {
    // Suppose the 0th is Home, 1st is Records,
    // so the new Connect/Devices tab is index=2
    return 2;
  }

  // Build Salomon bottom nav items
  List<SalomonBottomBarItem> _bottomNavItems() {
    List<SalomonBottomBarItem> items = [
      SalomonBottomBarItem(
        icon: const Icon(Icons.home),
        title: const Text("Home"),
        selectedColor: Colors.blue,
      ),
      SalomonBottomBarItem(
        icon: const Icon(Icons.bar_chart),
        title: const Text("Records"),
        selectedColor: Colors.green,
      ),

      // Always add Connect/Devices tab, even for web
      SalomonBottomBarItem(
        icon: const Icon(Icons.wifi),
        title: const Text("Connect"),
        selectedColor: Colors.cyanAccent,
      ),

      SalomonBottomBarItem(
        icon: const Icon(Icons.person),
        title: const Text("Profile"),
        selectedColor: Colors.purple,
      ),
    ];

    if (isAdmin) {
      items.add(
        SalomonBottomBarItem(
          icon: const Icon(Icons.admin_panel_settings),
          title: const Text("Admin"),
          selectedColor: Colors.redAccent,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Build pages for each bottom nav item
    List<Widget> _widgetOptions = [
      // Home
      kIsWeb ? _buildWebHomeContent() : _buildAndroidHomeContent(),

      // Records
      RecordsChartsScreen(
        device: selectedDevice,
        deviceId: selectedDevice?.deviceId ?? '',
      ),

      // Connect (Pair Devices) Tab
      PairDevicesScreen(),

      // Profile
      UserScreen(arguments: {}),
    ];

    // If admin, add Admin page
    if (isAdmin) {
      _widgetOptions.add(AdminPage());
    }

    // Ensure the selected index is within range
    if (_selectedIndex >= _widgetOptions.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: Stack(
        children: [
          Center(child: _widgetOptions.elementAt(_selectedIndex)),
          if (_showChat && selectedDevice != null)
            Positioned(
              top: 150,
              bottom: kIsWeb ? null : 80,
              right: 20,
              width: kIsWeb ? 600.0 : MediaQuery.of(context).size.width * 0.8,
              height: kIsWeb ? 400.0 : null,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.cyanAccent,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    padding: const EdgeInsets.only(right: 50.0),
                    child: ChatScreen(
                      onClose: () {
                        setState(() {
                          _showChat = false;
                        });
                      },
                      temperature: temperature,
                      humidity: humidity,
                      airQuality: airQuality,
                      gasLevels: gasLevels,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          if (index < _widgetOptions.length) {
            setState(() {
              _selectedIndex = index;
            });
          } else {
            print("Selected index $index is out of range.");
          }
        },
        items: _bottomNavItems(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showChat = !_showChat;
          });
        },
        backgroundColor: Colors.transparent,
        child: Image.asset(
          'asset/logo/chat_logo.png', // Correct asset path
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
