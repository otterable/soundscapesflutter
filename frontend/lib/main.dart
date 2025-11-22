import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';

// brand palette (mirrors your fitness tracker app)
const Color kNavy = Color(0xFF003056);
const Color kNavySoft = Color(0xFF00213C);
const Color kAccent = Color(0xFFFF5C00);
const Color kDanger = Color(0xFF9A031E);
const Color kFieldBorder = Color(0xFF1E3C57);
const Color kOk = Color(0xFF1C5434);
const Color kRulesBeige = Color(0xFFF5E9DA);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  // IMPORTANT: use HTTPS backend to avoid mixed-content on https://ermine.at/soundscapes
  final ApiService _api = ApiService(baseUrl: "https://soundscapes.ermine.at");

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _api.setAuthToken(prefs.getString('admin_token'));
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Widget _routeFor(String name) {
    if (!_ready) {
      return const _Splash();
    }

    // Admin login / dashboard routing unchanged
    if (name == "/admin") {
      return _api.isAuthed
          ? AdminDashboardScreen(api: _api)
          : AdminLoginScreen(api: _api);
    }

    // Single merged dashboard for all other routes, with optional initial category.
    String? initialCategory;

    if (name == "/all") {
      initialCategory = "All";
    } else if (name.startsWith("/category/")) {
      final cat = Uri.decodeComponent(name.substring("/category/".length));
      initialCategory = cat;
    } else {
      // "/" and any unknown route: default dashboard with "All" internally
      initialCategory = null;
    }

    return DashboardScreen(api: _api, initialCategory: initialCategory);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ermine Soundscapes',
      theme: _theme,
      onGenerateInitialRoutes: (initialRoute) => [
        MaterialPageRoute(
          builder: (_) => _routeFor(initialRoute),
          settings: RouteSettings(name: initialRoute),
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => _routeFor(settings.name ?? "/"),
        settings: settings,
      ),
    );
  }
}

final ThemeData _theme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
    backgroundColor: kNavy,
    elevation: 3,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      color: Colors.white,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kOk,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kOk,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kNavySoft,
    labelStyle: const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w600,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: kFieldBorder,
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: Colors.white,
        width: 1.2,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: kNavy,
    contentTextStyle: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    behavior: SnackBarBehavior.floating,
  ),
);

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
