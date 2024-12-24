import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

class ContactUsScreen extends StatelessWidget {
  final String email = "21901457@majancollege.edu.om";

  Future<void> _sendEmail(BuildContext context) async {
    const String email = '21901457@majancollege.edu.om';

    // Construct the mailto URL
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri.encodeQueryComponent(
        'subject=Support Request&body=Hello,\n\nI need help with...',
      ),
    );


    final String mailtoUrl = emailUri.toString();

    try {
      // Attempt to launch the default email client
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }

      else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final AndroidIntent intent = AndroidIntent(
          action: 'android.intent.action.SENDTO',
          data: 'mailto:$email',
          arguments: {
            'android.intent.extra.SUBJECT': 'Support Request',
            'android.intent.extra.TEXT': 'Hello,\n\nI need help with...',
          },
        );
        await intent.launch();
      }
      // If on the web, open Gmail's compose window as a fallback
      else if (kIsWeb) {
        final String fallbackUrl =
            'https://mail.google.com/mail/?view=cm&fs=1&to=$email&su=${Uri.encodeComponent('Support Request')}&body=${Uri.encodeComponent('Hello,\n\nI need help with...')}';
        final Uri fallbackUri = Uri.parse(fallbackUrl);

        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          throw 'No compatible email client found.';
        }
      }
      // If none of the above conditions are met, throw an error
      else {
        throw 'No compatible email client found.';
      }
    } catch (e) {
      // Display an error dialog if email client fails to open
      _showErrorDialog(context, "Failed to open email client: $e");
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Error",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        );
      },
    );
  }

  String _getBackgroundImage() {
    if (kIsWeb) {
      return "asset/backgrounds/Profile/web_bg.png"; // Background for web users
    } else {
      return "asset/backgrounds/Profile/profile_bg_l2_v2.png"; // Background for Android users
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_getBackgroundImage()),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 50),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          "Contact Us",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "If you have any questions or need assistance, feel free to reach out to us. We'd love to hear from you!",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () => _sendEmail(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Send Email",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
