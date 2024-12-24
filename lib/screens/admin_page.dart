// File: lib/screens/admin_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // We no longer call a one-time fetch here, since we'll use StreamBuilder in the UI
  }

  /// Deletes a user from Firestore.
  Future<void> deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "User deleted successfully.",
            style: GoogleFonts.pressStart2p(color: Colors.green),
          ),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error deleting user: $e",
            style: GoogleFonts.pressStart2p(color: Colors.red),
          ),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  /// Toggles the admin role of a user.
  Future<void> toggleAdmin(String userId, bool isCurrentlyAdmin) async {
    try {
      DocumentReference userRef =
      FirebaseFirestore.instance.collection('users').doc(userId);

      if (isCurrentlyAdmin) {
        // Remove admin role
        await userRef.update({'role': 'user'});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "User demoted from admin successfully.",
              style: GoogleFonts.pressStart2p(color: Colors.green),
            ),
            backgroundColor: Colors.black,
          ),
        );
      } else {
        // Add admin role
        await userRef.update({'role': 'admin'});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "User promoted to admin successfully.",
              style: GoogleFonts.pressStart2p(color: Colors.green),
            ),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error updating user role: $e",
            style: GoogleFonts.pressStart2p(color: Colors.red),
          ),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  /// Bans a user for a specified number of days.
  Future<void> _banUser(String userId, int banDays) async {
    final banUntilDate = DateTime.now().add(Duration(days: banDays));

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'bannedUntil': banUntilDate,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "User banned until ${DateFormat('yyyy-MM-dd').format(banUntilDate)}.",
            style: GoogleFonts.pressStart2p(color: Colors.green),
          ),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error banning user: $e",
            style: GoogleFonts.pressStart2p(color: Colors.red),
          ),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  /// Unbans a user by removing the 'bannedUntil' field.
  Future<void> _unbanUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'bannedUntil': FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "User has been unbanned successfully.",
            style: GoogleFonts.pressStart2p(color: Colors.green),
          ),
          backgroundColor: Colors.black,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error unbanning user: $e",
            style: GoogleFonts.pressStart2p(color: Colors.red),
          ),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  /// Ban Dialog
  void _showBanDialog(String userId, String username) {
    final TextEditingController banDaysController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            "Ban $username",
            style: GoogleFonts.pressStart2p(color: Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter the number of days to ban the user:",
                style: GoogleFonts.pressStart2p(color: Colors.greenAccent),
              ),
              TextField(
                controller: banDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter number of days",
                  hintStyle: GoogleFonts.pressStart2p(color: Colors.grey),
                ),
                style: GoogleFonts.pressStart2p(color: Colors.greenAccent),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.pressStart2p(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final banDays = int.tryParse(banDaysController.text.trim());
                if (banDays != null && banDays > 0) {
                  _banUser(userId, banDays);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Invalid number of days.",
                        style: GoogleFonts.pressStart2p(color: Colors.red),
                      ),
                      backgroundColor: Colors.black,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(
                "Ban",
                style: GoogleFonts.pressStart2p(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Unban Dialog
  void _showUnbanDialog(String userId, String username) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            "Unban $username",
            style: GoogleFonts.pressStart2p(color: Colors.green),
          ),
          content: Text(
            "Are you sure you want to unban this user immediately?",
            style: GoogleFonts.pressStart2p(color: Colors.greenAccent),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.pressStart2p(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _unbanUser(userId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(
                "Unban",
                style: GoogleFonts.pressStart2p(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds each user's Card.
  Widget _buildUserCard(DocumentSnapshot docSnapshot) {
    final data = docSnapshot.data() as Map<String, dynamic>?;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final String userId = docSnapshot.id;
    final String username = data['username'] ?? 'No Name';
    final String email = data['email'] ?? 'No Email';
    final DateTime registrationDate =
        (data['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final bool online = data['online'] ?? false;
    final String role = data['role'] ?? 'user';
    final DateTime? bannedUntil =
    (data['bannedUntil'] as Timestamp?)?.toDate();

    final bool isCurrentUser = userId == FirebaseAuth.instance.currentUser?.uid;
    final bool isUserAdmin = role == 'admin';
    final bool isUserBanned =
        bannedUntil != null && bannedUntil.isAfter(DateTime.now());

    return Card(
      color: Colors.black, // Dark background
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          color: Colors.cyanAccent,
          width: 2, // Neon cyan border
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0), // Add padding for spacing
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Username
            Row(
              children: [
                // Online status avatar
                CircleAvatar(
                  backgroundColor: online ? Colors.green : Colors.red,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                // Username
                Text(
                  username,
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(
                      color: Colors.green,
                      fontSize: 10, // Adjust as needed
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle section: user details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Email: $email",
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 8, // Adjust as needed
                    ),
                  ),
                ),
                Text(
                  "User ID: $userId",
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 8,
                    ),
                  ),
                ),
                Text(
                  "Joined: ${DateFormat('yyyy-MM-dd').format(registrationDate)}",
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 8,
                    ),
                  ),
                ),
                if (bannedUntil != null)
                  Text(
                    "Banned Until: ${DateFormat('yyyy-MM-dd').format(bannedUntil)}",
                    style: GoogleFonts.pressStart2p(
                      textStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 8,
                      ),
                    ),
                  ),
              ],
            ),

            // Bottom section: action buttons (only if not current user)
            if (!isCurrentUser) ...[
              const SizedBox(height: 10),
              // Admin Role Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  isUserAdmin ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                icon: Icon(
                  isUserAdmin ? Icons.remove_circle : Icons.add_circle,
                ),
                label: Text(
                  isUserAdmin ? "Remove Admin" : "Make Admin",
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(fontSize: 8),
                  ),
                ),
                onPressed: () {
                  // Confirm action
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.black,
                      title: Text(
                        isUserAdmin ? "Remove Admin" : "Add Admin",
                        style: GoogleFonts.pressStart2p(color: Colors.green),
                      ),
                      content: Text(
                        isUserAdmin
                            ? "Are you sure you want to demote this user from admin?"
                            : "Are you sure you want to promote this user to admin?",
                        style: GoogleFonts.pressStart2p(
                          color: Colors.greenAccent,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.pressStart2p(
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            toggleAdmin(userId, isUserAdmin);
                          },
                          child: Text(
                            isUserAdmin ? "Remove" : "Add",
                            style: GoogleFonts.pressStart2p(
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 5),

              // Delete Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                icon: const Icon(Icons.delete),
                label: Text(
                  "Delete User",
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(fontSize: 8),
                  ),
                ),
                onPressed: () {
                  // Confirm deletion
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.black,
                      title: Text(
                        "Delete User",
                        style: GoogleFonts.pressStart2p(color: Colors.green),
                      ),
                      content: Text(
                        "Are you sure you want to delete this user?",
                        style: GoogleFonts.pressStart2p(
                          color: Colors.greenAccent,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.pressStart2p(
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            deleteUser(userId);
                          },
                          child: Text(
                            "Delete",
                            style: GoogleFonts.pressStart2p(
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 5),

              // Ban Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                icon: const Icon(Icons.gavel, color: Colors.white),
                label: Text(
                  "Ban User",
                  style: GoogleFonts.pressStart2p(
                    textStyle: const TextStyle(fontSize: 8),
                  ),
                ),
                onPressed: () {
                  _showBanDialog(userId, username);
                },
              ),
              const SizedBox(height: 5),

              // Unban Button
              if (isUserBanned)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                  ),
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                  label: Text(
                    "Unban User",
                    style: GoogleFonts.pressStart2p(
                      textStyle: const TextStyle(fontSize: 8),
                    ),
                  ),
                  onPressed: () {
                    _showUnbanDialog(userId, username);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Admin Page",
          style: GoogleFonts.pressStart2p(
            textStyle: const TextStyle(
              color: Colors.green,
              fontSize: 12,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),

      /// Instead of manually fetching users, we use a StreamBuilder to listen
      /// to real-time updates from Firestore's 'users' collection.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(), // Real-time updates
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No users found.",
                style: GoogleFonts.pressStart2p(
                  textStyle: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) =>
                _buildUserCard(docs[index]),
          );
        },
      ),
    );
  }
}
