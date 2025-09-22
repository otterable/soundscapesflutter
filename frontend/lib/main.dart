import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/category_screen.dart';
import 'screens/all_files_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';

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
  // Backend is plain HTTP on 8083
  final ApiService _api = ApiService(baseUrl: "http://soundscapes.ermine.at:8083");
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _api.setAuthToken(prefs.getString('admin_token'));
    if (mounted) setState(() => _ready = true);
  }

  Widget _routeFor(String name) {
    if (!_ready) return const _Splash();

    if (name == "/") return DashboardScreen(api: _api);
    if (name == "/all") return AllFilesScreen(api: _api);

    if (name == "/admin") {
      // Route guard: decide here
      return _api.isAuthed
          ? AdminDashboardScreen(api: _api)
          : AdminLoginScreen(api: _api);
    }

    if (name.startsWith("/category/")) {
      final cat = Uri.decodeComponent(name.substring("/category/".length));
      return CategoryScreen(api: _api, categoryName: cat);
    }

    // Fallback
    return DashboardScreen(api: _api);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ermine Soundscapes',
      theme: _theme,

      // FIX 1: Handle browser’s initial path (e.g. /admin) before routes are used.
      onGenerateInitialRoutes: (initialRoute) => [
        MaterialPageRoute(
          builder: (_) => _routeFor(initialRoute),
          settings: RouteSettings(name: initialRoute),
        )
      ],

      // FIX 2: Use a single guard for all subsequent navigations.
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
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B98E0), brightness: Brightness.dark),
  useMaterial3: true,
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    bodyMedium: TextStyle(fontSize: 16),
  ),
);

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator())),
    );
  }
}
