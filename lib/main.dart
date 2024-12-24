import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/records_charts_screen.dart';
import 'screens/pair_devices_screen.dart';
import 'screens/contact_us_screen.dart';
import 'screens/about_us.dart';
import 'screens/user_screen.dart';
import 'screens/home_screen_with_air_quality.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'firebase_options.dart';
import 'screens/admin_page.dart';
import 'restart_widget.dart'; // Import RestartWidget


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    RestartWidget(
      child: const MyApp(), // Wrap your root widget here
    ),
  );
}
// Initialize the Vertex AI

// Gemini 1.5
final model =
FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zero',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const MainHomeScreen(); // Always direct to MainHomeScreen
          }
          return const LoginScreen();
        },
      ),


      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/records_charts': (context) => RecordsChartsScreen(deviceId: '',),
        '/pair_devices': (context) => PairDevicesScreen(),
        '/contact_us': (context) => ContactUsScreen(),
        '/home_screen': (context) => const MainHomeScreen(),
        '/admin': (context) => AdminPage(),
        '/about':(context)=> AboutUsPage(),



      },

      onGenerateRoute: (settings) {
        if (settings.name == '/user') {
          final user = FirebaseAuth.instance.currentUser;
          final args = {
            'profilePhoto': user?.photoURL ?? '',
            'username': user?.displayName ?? 'No Name',
            'email': user?.email ?? 'No Email',
          };

          return MaterialPageRoute(
            builder: (context) => UserScreen(arguments: args),
          );
        }
        return null;
      },


    );
  }
}
