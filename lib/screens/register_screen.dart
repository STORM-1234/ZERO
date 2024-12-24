import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _passwordObscured = true;
  bool _confirmPasswordObscured = true;

  File? _profileImage;

  Future<void> _pickImage() async {
    print("Opening image picker...");
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      print("Image selected: ${pickedFile.path}");
    } else {
      print("No image selected.");
    }
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        print("Attempting user registration...");
        final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final User? user = userCredential.user;

        if (user != null) {
          print("User created successfully.");
          print("User UID: ${user.uid}");
          print("User Email: ${user.email}");
          print("User Display Name: ${user.displayName}");

          String? profileImageUrl;
          if (_profileImage != null) {
            print("Uploading profile image...");
            try {
              final storageRef = FirebaseStorage.instance
                  .ref()
                  .child('profile_images')
                  .child('${user.uid}.jpg');
              await storageRef.putFile(_profileImage!);
              profileImageUrl = await storageRef.getDownloadURL();
              print("Profile image uploaded: $profileImageUrl");
            } catch (e) {
              print("Error uploading profile image: $e");
              profileImageUrl = null;
            }
          } else {
            print("No profile image selected.");
          }

          print("Saving user data to Firestore...");
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'email': _emailController.text.trim(),
              'username': _usernameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'profileImageUrl': profileImageUrl,
              'createdAt': DateTime.now(),
            });
            print("User data saved to Firestore successfully.");
          } catch (e) {
            print("Error saving user data to Firestore: $e");
          }

          Navigator.pushReplacementNamed(context, '/home_screen');
        } else {
          print("User creation failed. User object is null.");
        }
      } catch (e) {
        print("Error during registration: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } else {
      print("Form validation failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define the breakpoint for responsiveness
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth >= 600; // You can adjust this breakpoint

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer 1
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("asset/backgrounds/login_register/bg_layer_1_v2.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Interactive Content Layer
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 50.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.black,
                      child: Image.asset(
                        'asset/logo/zero.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Register Card with Responsive Width
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLargeScreen ? 500 : double.infinity, // Set maxWidth for large screens
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Profile Image Picker
                              GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundImage:
                                  _profileImage != null ? FileImage(_profileImage!) : null,
                                  child: _profileImage == null
                                      ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                                      : null,
                                  backgroundColor: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Email TextField
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _emailController,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.email, color: Colors.black),
                                  hintText: "example@gmail.com",
                                  hintStyle: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Username TextField
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.person, color: Colors.black),
                                  hintText: "Enter your username",
                                  hintStyle: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Username is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Phone TextField
                              TextField(
                                style: const TextStyle(color: Colors.black),
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.phone, color: Colors.black),
                                  hintText: "Enter your phone number",
                                  hintStyle: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Password TextField
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _passwordController,
                                obscureText: _passwordObscured,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.lock, color: Colors.black),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordObscured
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordObscured = !_passwordObscured;
                                      });
                                    },
                                  ),
                                  hintText: "Enter your password",
                                  hintStyle: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Confirm Password TextField
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _confirmPasswordController,
                                obscureText: _confirmPasswordObscured,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.lock, color: Colors.black),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _confirmPasswordObscured
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _confirmPasswordObscured = !_confirmPasswordObscured;
                                      });
                                    },
                                  ),
                                  hintText: "Confirm your password",
                                  hintStyle: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Register Button
                              ElevatedButton(
                                onPressed: _registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "Register",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF2a622a),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),

                              // Already have an account?
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                },
                                child: const Text(
                                  "Already have an account? Login",
                                  style: TextStyle(
                                    color: Color(0xFF00BCD4),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
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
            ),
          ),
          // Background Layer 2 on Top
          IgnorePointer(
            ignoring: true,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("asset/backgrounds/login_register/bg_layer_2_v2.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
