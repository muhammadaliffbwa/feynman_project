import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'screens/home_page.dart';

// Public by design — reCAPTCHA site keys are meant to ship in client code,
// unlike the Gemini key, which never appears here at all.
const _recaptchaSiteKey = '6LeHs34tAAAAAM0eJHd8UH_pzeehd58rHI7NFDzs';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(_recaptchaSiteKey),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode 
            ? AndroidProvider.debug 
            : AndroidProvider.playIntegrity,
      );
    }
  }catch (e) {
    debugPrint('Firebase setup failed: $e');
  }

  GoogleFonts.poppins();
  GoogleFonts.merriweather();
  GoogleFonts.courierPrime();
  GoogleFonts.caveat();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color.fromARGB(255, 10, 108, 62);

    return MaterialApp(
      title: 'Feynman',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: HomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}