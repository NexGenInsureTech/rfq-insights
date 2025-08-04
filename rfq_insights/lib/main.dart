import 'package:flutter/material.dart';
import 'package:rfq_insights/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rfq_insights/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures that Flutter engine is initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RFQ Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // We'll start with the authentication screen, and if a user is logged in,
      // we'll navigate to the RFQ list screen.
      home: AuthScreen(), // We'll create this next
      // Or, if you want to jump straight to the list for now (without auth setup):
      // home: RfqListScreen(),
    );
  }
}
