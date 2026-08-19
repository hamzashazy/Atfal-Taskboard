import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'api.dart';
import 'meta.dart';
import 'push.dart';
import 'screens/admin_screen.dart';
import 'screens/city_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await Session.load();
  unawaited(Push.init());
  runApp(const AtfalApp());
}

class AtfalApp extends StatelessWidget {
  const AtfalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: C.brand700,
      primary: C.brand700,
      surface: Colors.white,
    );
    return MaterialApp(
      title: 'Atfal Taskboard',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: C.bg,
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: C.brand800,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: C.brand700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: C.gray600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: const BorderSide(color: C.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: C.brand700,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: C.gray50,
          selectedColor: C.brand700,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          secondaryLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: C.border)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: C.brand50,
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          height: 64,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: states.contains(WidgetState.selected)
                    ? C.brand800
                    : C.gray500,
              )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? C.brand800
                    : C.gray500,
              )),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.all(14),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: C.brand700,
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        dividerTheme: const DividerThemeData(color: C.gray100, space: 1),
        textTheme: Typography.blackMountainView
            .apply(bodyColor: C.text, displayColor: C.text),
      ),
      routes: {
        '/': (_) => const DashboardScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/city': (_) => const CityScreen(),
        '/admin': (_) => const AdminScreen(),
      },
      initialRoute: _initialRoute(),
    );
  }

  String _initialRoute() {
    final s = Session.current;
    if (s == null) return '/login';
    return s.isAdmin ? '/admin' : '/city';
  }
}
