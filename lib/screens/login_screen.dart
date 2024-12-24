// File: lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:google_fonts/google_fonts.dart'; // For consistent styling
import 'package:intl/intl.dart'; // For date formatting

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  /// Google Sign-In Method
  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
      // Ensure any previous Google sessions are cleared
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User canceled the Google sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user != null) {
        final DocumentReference userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

        // If user doc doesn't exist, create it
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'username': user.displayName ?? 'No Name',
            'phone': user.phoneNumber ?? 'N/A',
            'profileImageUrl': user.photoURL ?? '',
            'registrationDate': FieldValue.serverTimestamp(),
            'role': 'user', // Default role
            // We won't set 'online' here, we'll do it after the ban check in handleLogin
          });
        }
      }

      // After Google sign-in, handle post-login checks (ban status, etc.)
      await handleLogin(context, userCredential.user);
      return userCredential;
    } catch (e) {
      print('Error during Google sign-in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during Google sign-in: $e")),
      );
      return null;
    }
  }

  /// Email/Password Sign-In Method
  Future<void> signInWithEmailPassword(
      BuildContext context, String email, String password) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // After Email/Password sign-in, handle post-login checks
      await handleLogin(context, userCredential.user);
    } on FirebaseAuthException catch (e) {
      String message = "Login failed.";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password provided.";
      } else {
        message = e.message ?? "An error occurred.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      print('Error during email/password sign-in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  /// Password Reset Method
  Future<void> resetPassword(BuildContext context) async {
    TextEditingController phoneController = TextEditingController();
    // Placeholder approach. You can enhance it with OTP verification, new password fields, etc.

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  hintText: "Enter your phone number",
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("OTP feature not implemented yet.")),
                );
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  /// Handle Post-Login Actions (e.g., Ban Check, Setting 'online' Status)
  Future<void> handleLogin(BuildContext context, User? user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User is null after sign-in.")),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();

        // Check ban status
        final bannedUntilTimestamp = data?['bannedUntil'] as Timestamp?;
        DateTime? bannedUntil;
        if (bannedUntilTimestamp != null) {
          bannedUntil = bannedUntilTimestamp.toDate();
        }

        // If user is currently banned
        if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "You are banned until ${DateFormat('yyyy-MM-dd').format(bannedUntil)}.",
                style: GoogleFonts.pressStart2p(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          // Set 'online' to false in case it was previously true
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'online': false});

          // Sign the user out
          await FirebaseAuth.instance.signOut();
          return;
        }

        // If user is not banned, set 'online' to true
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'online': true});

        // ---- NEW: Show a modern success indicator (MaterialBanner) ---- //
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: Colors.greenAccent,
            content: const Text(
              "Login successful!",
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text("DISMISS"),
              ),
            ],
          ),
        );

        // Hide the banner after a short delay and navigate to home
        Future.delayed(const Duration(seconds: 2), () {
          // Remove the banner
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

          // Navigate to home screen
          Navigator.pushReplacementNamed(context, '/home_screen');
        });
        // ---- END NEW SECTION ---- //

      } else {
        // If user doc not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found in database.")),
        );
        // Sign out
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print("Error during login: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during login: $e")),
      );
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      body: ResponsiveWrapper.builder(
        Stack(
          fit: StackFit.expand,
          children: [
            // Background Layer 1
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    "asset/backgrounds/login_register/bg_layer_1_v2.jpg",
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Buttons and Card Content Layer
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double cardWidth =
                      constraints.maxWidth < 800 ? double.infinity : 500;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.black,
                            child: Image.asset(
                              'asset/logo/zero.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Login Card
                          Container(
                            width: cardWidth,
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
                            child: Column(
                              children: [
                                // Email TextField
                                TextField(
                                  controller: emailController,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.email,
                                        color: Colors.black),
                                    hintText: "example@gmail.com",
                                    hintStyle: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14, // Increased font size
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Password Field
                                PasswordField(controller: passwordController),
                                const SizedBox(height: 10),

                                // Forgot Password
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        resetPassword(context);
                                      },
                                      child: const Text(
                                        "Forgot password?",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14, // Increased font size
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),

                                // Sign In Button
                                ElevatedButton(
                                  onPressed: () async {
                                    String email =
                                    emailController.text.trim();
                                    String password =
                                    passwordController.text.trim();

                                    if (email.isEmpty || password.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Please enter email and password.",
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    await signInWithEmailPassword(
                                        context, email, password);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15, horizontal: 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Sign in",
                                    style: TextStyle(
                                      fontSize: 16, // Increased font size
                                      color: Color(0xFF2a622a),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Register Button
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/register');
                                  },
                                  child: const Text(
                                    "Don't have an account? Sign up here",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14, // Increased font size
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // OR Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withOpacity(0.5),
                                  thickness: 1,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  "OR",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withOpacity(0.5),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Google Sign-In
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton(
                              onPressed: () async {
                                await signInWithGoogle(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(60, 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Image.asset(
                                'asset/logo/googlelogo.png',
                                height: 40,
                                width: 40,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Sign-In Text
                          const Text(
                            "Google Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14, // Increased font size
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
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
                    image: AssetImage(
                      "asset/backgrounds/login_register/bg_layer_2.png",
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
        maxWidth: 1920,
        minWidth: 450,
        defaultScale: true,
        breakpoints: const [
          ResponsiveBreakpoint.resize(450, name: MOBILE),
          ResponsiveBreakpoint.autoScale(800, name: TABLET),
          ResponsiveBreakpoint.resize(1000, name: DESKTOP),
          ResponsiveBreakpoint.autoScale(2460, name: '4K'),
        ],
      ),
    );
  }
}

/// PasswordField Widget
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  const PasswordField({super.key, required this.controller});

  @override
  _PasswordFieldState createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock, color: Colors.black),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.black,
          ),
          onPressed: _togglePasswordVisibility,
        ),
        hintText: "Enter your password",
        hintStyle: const TextStyle(
          color: Colors.black,
          fontSize: 14, // Increased font size
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }
}
