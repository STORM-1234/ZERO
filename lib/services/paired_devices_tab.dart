import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zerov7/models/device.dart';
import 'package:zerov7/restart_widget.dart';

class PairedDevicesTab extends StatefulWidget {
  final VoidCallback onDevicePaired;

  const PairedDevicesTab({
    Key? key,
    required this.onDevicePaired,
  }) : super(key: key);

  @override
  _PairedDevicesTabState createState() => _PairedDevicesTabState();
}

class _PairedDevicesTabState extends State<PairedDevicesTab> {
  final List<Device> pairedDevices = [];
  bool isLoading = true;

  late DatabaseReference devicesRef;
  late Stream<DatabaseEvent> devicesStream;
  late String userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    devicesRef = FirebaseDatabase.instance.ref('users/$userId/devices');
    devicesStream = devicesRef.onValue;

    devicesStream.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      List<Device> devicesList = [];

      if (data != null) {
        Map<dynamic, dynamic> devicesMap = data as Map<dynamic, dynamic>;
        devicesMap.forEach((key, value) {
          devicesList.add(Device.fromMap(value, key));
        });
      }

      setState(() {
        pairedDevices
          ..clear()
          ..addAll(devicesList);
        isLoading = false;
      });
    });
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      await devicesRef.child(deviceId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device removed successfully')),
      );
      RestartWidget.restartApp(context); // Restart the app after deletion
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove device: $e')),
      );
    }
  }

  Future<void> updateNickname(String deviceId, String currentNickname) async {
    TextEditingController nicknameController =
    TextEditingController(text: currentNickname);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Update Nickname"),
          content: TextField(
            controller: nicknameController,
            decoration: const InputDecoration(hintText: "Enter new nickname"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty) {
                  await devicesRef
                      .child(deviceId)
                      .update({'nickname': newNickname});

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nickname updated successfully')),
                  );
                  setState(() {});
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  /// Toggle the 'selected' state of this device
  Future<void> toggleDeviceSelection(Device device, bool newValue) async {
    if (newValue) {
      // If turning ON, unselect all others, then select this one
      for (Device d in pairedDevices) {
        if (d.deviceId != device.deviceId && d.selected) {
          // Set them to false
          await devicesRef.child(d.deviceId).update({'selected': false});
        }
      }
      // Now set this device to true
      await devicesRef.child(device.deviceId).update({'selected': true});
    } else {
      // If turning OFF, just set this device's selected to false
      await devicesRef.child(device.deviceId).update({'selected': false});
    }

    // After update, restart app
    RestartWidget.restartApp(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pairedDevices.isEmpty) {
      return const Center(
        child: Text(
          "No devices paired.",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final snapshot = await devicesRef.get();
        final data = snapshot.value;
        List<Device> devicesList = [];
        if (data != null) {
          Map<dynamic, dynamic> devicesMap = data as Map<dynamic, dynamic>;
          devicesMap.forEach((key, value) {
            devicesList.add(Device.fromMap(value, key));
          });
        }
        setState(() {
          pairedDevices
            ..clear()
            ..addAll(devicesList);
        });
      },
      child: ListView.builder(
        itemCount: pairedDevices.length,
        itemBuilder: (context, index) {
          final device = pairedDevices[index];
          final bool isSelected = device.selected;

          // Build the Card as usual
          final card = Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.device_hub, color: Colors.cyanAccent),
              title: Text(
                device.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Added on: ${device.addedAt}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (device.nickname != null)
                    Text(
                      "Nickname: ${device.nickname}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The toggle switch
                  Switch(
                    value: isSelected,
                    onChanged: (value) => toggleDeviceSelection(device, value),
                    activeColor: Colors.cyanAccent,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () =>
                        updateNickname(device.deviceId, device.nickname ?? ""),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      bool? confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Remove Device"),
                            content: const Text("Are you sure you want to remove this device?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Remove"),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmDelete == true) {
                        await deleteDevice(device.deviceId);
                      }
                    },
                  ),
                ],
              ),
            ),
          );

          // For web, wrap in a Center + ConstrainedBox to limit max width.
          // For mobile, just return the card as is.
          return kIsWeb
              ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: card,
            ),
          )
              : card;
        },
      ),
    );
  }
}
