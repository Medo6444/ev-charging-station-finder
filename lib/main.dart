import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grad02/common/glob.dart';
import 'package:grad02/common/my_http_overrides.dart';
import 'package:grad02/common/service_call.dart';
import 'package:grad02/common/socket_manager.dart';
import 'package:grad02/firebase/auth_layout.dart';
import 'package:grad02/polylines/location_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

SharedPreferences? prefs;

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  ServiceCall.userUUID = Glob.udValueString("uuid");
  if (ServiceCall.userUUID == "") {
    ServiceCall.userUUID = const Uuid().v6();
    Glob.udStringSet(ServiceCall.userUUID, "uuid");
  }
  SocketManager.shared.initSocket();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
  LocationManager.shared.initLocation();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 5)).then(
      (value) => Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => AuthLayout())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          height: 200.0,
          width: 200.0,
          child: Lottie.asset("assets/animations/intro.json"),
        ),
      ),
    );
  }
}
