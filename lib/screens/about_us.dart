import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
\

    final String backgroundAsset = kIsWeb
        ? "asset/backgrounds/Profile/red_bg.png"         // Web
        : "asset/backgrounds/Profile/profile_bg_l2.png"; // Android


    const String aboutText =
        "Welcome to our app!\n\n"
        "Our mission is to provide a seamless air quality monitoring experience "
        "powered by cutting-edge IoT and AI technologies. With real-time updates, "
        "intuitive design, and reliable data, we aim to help you breathe better "
        "and live healthier.\n\n"
        "“Our vision is to empower communities with actionable, real-time insights "
        "into air quality, bridging the gap between technology, environment, "
        "and everyday life. Through cutting-edge IoT solutions, user-friendly "
        "interfaces, and robust analytics, we strive to help people breathe cleaner air, "
        "live healthier lives, and build a more sustainable future for everyone.”\n\n"
        "This is a Solo Project work done by nabin nejimudeen "
        "for the final year graduation project at Majan University College. "
        "This project was completed with the help and guidance of Dr Manju.";

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(backgroundAsset),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 50),

                  // Centered scrollable text about your mission/vision
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          // If on web, constrain width to 600. Else, no max limit.
                          constraints: BoxConstraints(
                            maxWidth: kIsWeb ? 600 : double.infinity,
                          ),
                          child: const Column(
                            children: [
                              Text(
                                "About Us",
                                style: TextStyle(
                                  fontSize: 20,       // Header font size
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 20),
                              Text(
                                aboutText,
                                style: TextStyle(
                                  fontSize: 10,      // Body font size
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
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
