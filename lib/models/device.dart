// File: lib/models/device.dart
class Device {
  final String deviceId;
  final String name;
  final String addedAt;
  final String email;
  final String? nickname;
  final bool selected; // NEW: track if this device is selected

  Device({
    required this.deviceId,
    required this.name,
    required this.addedAt,
    required this.email,
    this.nickname,
    required this.selected,
  });

  factory Device.fromMap(Map<dynamic, dynamic> map, String deviceId) {
    return Device(
      deviceId: deviceId,
      name: map['name'] ?? 'Unknown Device',
      addedAt: map['added_at'] ?? '',
      email: map['email'] ?? '',
      nickname: map['nickname'],
      selected: map['selected'] == true, // default false if null
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'added_at': addedAt,
      'email': email,
      'nickname': nickname,
      'selected': selected,
    };
  }

  @override
  String toString() {
    return 'Device(deviceId: $deviceId, name: $name, addedAt: $addedAt, email: $email, nickname: $nickname, selected: $selected)';
  }
}
