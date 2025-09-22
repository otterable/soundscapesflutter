import 'dart:math';
import 'package:flutter/material.dart';
import '../api_service.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<SoundCategory>> _future;
  final List<Color> _buttonColors = const [
    Color(0xFF003049),
    Color(0xFFD62828),
    Color(0xFFF77F00),
    Color(0xFFFCBF49),
    Color(0xFFEAE2B7),
    Color(0xFF9CB380),
    Color(0xFF1B98E0),
    Color(0xFF2E933C),
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchCategories();
  }

  List<Color> _shuffledColors(int length) {
    final colors = List<Color>.from(_buttonColors);
    colors.shuffle(Random());
    final out = <Color>[];
    for (var i = 0; i < length; i++) {
      out.add(colors[i % colors.length]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoMaxWidth = width < 768 ? 0.60 : 0.20;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ermine Soundscapes"),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Admin",
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.pushNamed(context, "/admin"),
          ),
        ],
      ),
      body: FutureBuilder<List<SoundCategory>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Error loading soundscapes:\n${snap.error}", textAlign: TextAlign.center),
              ),
            );
          }
          final categories = snap.data ?? [];
          final shuffled = _shuffledColors(categories.length + 1);

          final logo = Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.api.asset("/static/logo.png"),
                width: MediaQuery.sizeOf(context).width * logoMaxWidth,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );

          if (categories.isEmpty) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  logo,
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "No soundscapes on the server.\nAdmins: open the Admin page to create a category and upload files.",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, "/admin"),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text("Admin Area"),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                logo,
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        "Self-created Soundscapes, of pretty much anything.",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, shadows: [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Ermine soundscapes are seamless — they can be looped indefinitely, without any cuts.",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, shadows: [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Filter by category using the buttons below.",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, shadows: [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _CategoryButton(
                      label: "All",
                      color: shuffled.first,
                      onTap: () => Navigator.pushNamed(context, "/all"),
                    ),
                    for (var i = 0; i < categories.length; i++)
                      _CategoryButton(
                        label: categories[i].name,
                        color: shuffled[i + 1],
                        onTap: () => Navigator.pushNamed(
                          context,
                          "/category/${Uri.encodeComponent(categories[i].name)}",
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> with SingleTickerProviderStateMixin {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final textColor = ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
