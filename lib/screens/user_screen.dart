import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'about_us.dart';
import 'contact_us_screen.dart';

class UserScreen extends StatefulWidget {
  final Map<String, String> arguments;

  const UserScreen({Key? key, required this.arguments}) : super(key: key);

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  String profilePhoto = '';
  String username = 'No Name';
  String email = 'No Email';
  String phone = 'N/A';
  String registrationDate = 'N/A';
  bool isEmailPasswordLogin = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        isEmailPasswordLogin =
            user.providerData.any((info) => info.providerId == 'password');

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          setState(() {
            profilePhoto = data?['profileImageUrl'] ??
                widget.arguments['profilePhoto'] ??
                '';
            username = data?['username'] ??
                widget.arguments['username'] ??
                'No Name';
            email = data?['email'] ?? user.email ?? 'No Email';
            phone = data?['phone'] ?? 'N/A';
            registrationDate = user.metadata.creationTime
                ?.toLocal()
                .toString()
                .split(' ')[0] ??
                'N/A';
          });
        }
      }
    } catch (e) {
      // Handle errors if necessary
      print("Error initializing user data: $e");
    }
  }

  Future<void> _changeProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take Photo"),
              onTap: () {
                Navigator.pop(context);
                // Implement camera functionality here
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                // Implement gallery selection functionality here
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editProfileField(String field, String currentValue) async {
    TextEditingController controller = TextEditingController(text: currentValue);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit $field"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter new $field"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final newValue = controller.text.trim();
                if (newValue.isNotEmpty && newValue != currentValue) {
                  try {
                    final user = FirebaseAuth.instance.currentUser;

                    if (user != null) {
                      if (field == "Email") {
                        // Re-authenticate the user for email changes
                        final credentials = EmailAuthProvider.credential(
                          email: user.email!,
                          password: await _getPasswordFromUser(),
                        );

                        await user.reauthenticateWithCredential(credentials);

                        // Update Firebase Authentication email
                        await user.updateEmail(newValue);

                        // Update Firestore database
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({'email': newValue});

                        setState(() {
                          email = newValue;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Email updated successfully.")),
                        );
                      } else {
                        // Directly update other fields in Firestore without re-authentication
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({field.toLowerCase(): newValue});

                        if (field == "Username") {
                          setState(() {
                            username = newValue;
                          });
                        } else if (field == "Phone") {
                          setState(() {
                            phone = newValue;
                          });
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text("$field updated successfully.")),
                        );
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to update $field: $e")),
                    );
                  }
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

  Future<String> _getPasswordFromUser() async {
    TextEditingController passwordController = TextEditingController();
    String? password;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Re-authentication Required"),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Enter your password"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                password = null;
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                password = passwordController.text.trim();
                Navigator.pop(context);
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );

    if (password == null || password!.isEmpty) {
      throw Exception("Password is required for re-authentication.");
    }

    return password!;
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User is not logged in.")),
      );
      return;
    }

    TextEditingController currentPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    bool isCurrentPasswordObscured = true;
    bool isNewPasswordObscured = true;

    bool reAuthenticated = false;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.cyanAccent, width: 2),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kIsWeb ? 400 : double.infinity, // Adjust width for web users
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Change Password",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Current Password Field
                      TextField(
                        controller: currentPasswordController,
                        obscureText: isCurrentPasswordObscured,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.6),
                          labelText: "Enter current password",
                          labelStyle: const TextStyle(color: Colors.cyanAccent),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isCurrentPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.cyanAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                isCurrentPasswordObscured =
                                !isCurrentPasswordObscured;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent, width: 2),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      // New Password Field
                      TextField(
                        controller: newPasswordController,
                        obscureText: isNewPasswordObscured,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.6),
                          labelText: "Enter new password",
                          labelStyle: const TextStyle(color: Colors.cyanAccent),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isNewPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.cyanAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                isNewPasswordObscured = !isNewPasswordObscured;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent, width: 2),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              reAuthenticated = false;
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.cyanAccent),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              reAuthenticated = true;
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Submit",
                              style: TextStyle(color: Colors.cyanAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    // If user canceled, do nothing
    if (!reAuthenticated) return;

    try {
      // Re-authenticate the user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // Update the password
      final newPassword = newPasswordController.text.trim();
      if (newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New password cannot be empty.")),
        );
      }
    } catch (e) {
      print("Error changing password: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
  void _about() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AboutUsPage()),
    );
  }

  void _contact() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ContactUsScreen()),
    );
  }


  /// Updated logout to set 'online': false before signing out.
  Future<void> _logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Set online to false in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'online': false});
    }

    // Then sign out
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layers
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("asset/backgrounds/Profile/profile_bg_l1.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          IgnorePointer(
            ignoring: true,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image:
                  AssetImage("asset/backgrounds/Profile/profile_bg_l2.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: kIsWeb
                  ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildUserProfileContent(),
                ),
              )
                  : _buildUserProfileContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 70,
              backgroundColor: Colors.grey[800],
              backgroundImage:
              profilePhoto.isNotEmpty ? NetworkImage(profilePhoto) : null,
              child: profilePhoto.isEmpty
                  ? const Icon(Icons.account_circle, size: 70, color: Colors.white)
                  : null,
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: _changeProfilePhoto,
                child: const CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.add, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => _editProfileField("Username", username),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 250),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Active since: $registrationDate",
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Personal Information",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Email Information
        Card(
          color: Colors.grey[900],
          child: ListTile(
            title: const Text("Email", style: TextStyle(color: Colors.grey,),),
            subtitle: Text(email, style: const TextStyle(color: Colors.white,fontSize: 13)),
          ),
        ),
        const SizedBox(height: 10),
        // Phone Information
        Card(
          color: Colors.grey[900],
          child: ListTile(
            title: const Text("Phone", style: TextStyle(color: Colors.grey)),
            subtitle: Text(phone, style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editProfileField("Phone", phone),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Utilities",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isEmailPasswordLogin)
          Card(
            color: Colors.grey[900],
            child: ListTile(
              leading: const Icon(Icons.lock, color: Colors.blue),
              title: const Text(
                "Change Password",
                style: TextStyle(color: Colors.white),
              ),
              onTap: _changePassword,
            ),
          ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey[900],
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.blue),
            title: const Text(
              "Log Out",
              style: TextStyle(color: Colors.white),
            ),
            onTap: _logout,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey[900],
          child: ListTile(
            leading: const Icon(Icons.logo_dev, color: Colors.blue),
            title: const Text(
              "About US",
              style: TextStyle(color: Colors.white),
            ),
            onTap: _about,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey[900],
          child: ListTile(
            leading: const Icon(Icons.email, color: Colors.blue),
            title: const Text(
              "Contact US",
              style: TextStyle(color: Colors.white),
            ),
            onTap: _contact,
          ),
        ),
      ],
    );
  }
}
