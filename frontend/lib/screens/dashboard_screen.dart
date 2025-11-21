// lib/screens/dashboard_screen.dart

import 'dart:math';
import 'dart:html' as html; // for web: open ermine.at

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../widgets/audio_grid.dart';

// brand palette (mirrors fitness tracker app)
const Color kNavy = Color(0xFF003056);
const Color kNavySoft = Color(0xFF00213C);
const Color kAccent = Color(0xFFFF5C00);
const Color kDanger = Color(0xFF9A031E);
const Color kFieldBorder = Color(0xFF1E3C57);
const Color kOk = Color(0xFF1C5434);
const Color kRulesBeige = Color(0xFFF5E9DA);

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  final String? initialCategory; // can be "All" or a category name

  const DashboardScreen({
    super.key,
    required this.api,
    this.initialCategory,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<SoundCategory>> _future;

  // 0 = All soundscapes, 1..N = specific categories
  int _selectedTabIndex = 0;

  // sorting mode: 'name', 'name_desc', 'random'
  String _sortMode = 'name';

  // ensure we only apply initialCategory once after data load
  bool _initialCategoryApplied = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchCategories();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.api.fetchCategories();
      _initialCategoryApplied = false;
    });
  }

  Widget _navyCard({required Widget child}) {
    return Card(
      color: kNavy.withOpacity(0.92),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: child,
      ),
    );
  }

  List<SoundFile> _sortedFiles(List<SoundFile> files) {
    final out = List<SoundFile>.from(files);
    switch (_sortMode) {
      case 'name_desc':
        out.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case 'random':
        out.shuffle(Random());
        break;
      case 'name':
      default:
        out.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        centerTitle: true,
        leading: IconButton(
          tooltip: "Back to ermine.at",
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            html.window.location.href = "https://ermine.at";
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/erminelogo.png',
              height: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              "Soundscapes",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: "Filter & sort",
            color: kNavy,
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _sortMode = value;
              });
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'name',
                child: Row(
                  children: [
                    if (_sortMode == 'name')
                      const Icon(Icons.check, color: Colors.white, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "Name A–Z",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'name_desc',
                child: Row(
                  children: [
                    if (_sortMode == 'name_desc')
                      const Icon(Icons.check, color: Colors.white, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "Name Z–A",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'random',
                child: Row(
                  children: [
                    if (_sortMode == 'random')
                      const Icon(Icons.check, color: Colors.white, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "Random order",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: "Admin",
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, "/admin"),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/molen.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.30),
          ),
          SafeArea(
            child: FutureBuilder<List<SoundCategory>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _navyCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.error_outline, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Error loading soundscapes",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${snap.error}",
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final categories = snap.data ?? [];

                // flatten all files for "All" view
                final allFiles = <SoundFile>[];
                for (final c in categories) {
                  allFiles.addAll(c.files);
                }

                final width = MediaQuery.of(context).size.width;
                final logoMaxWidth = width < 768 ? 0.60 : 0.20;

                final logo = Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      widget.api.asset("/static/logo.png"),
                      width: width * logoMaxWidth,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                );

                if (categories.isEmpty || allFiles.isEmpty) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Center(child: logo),
                        const SizedBox(height: 12),
                        _navyCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "No soundscapes yet",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                "There are no soundscapes on the server yet.\n"
                                "Admins can open the Admin area to create categories and upload files.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, "/admin"),
                          icon: const Icon(Icons.admin_panel_settings,
                              color: Colors.white),
                          label: const Text(
                            "Open Admin area",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // apply initialCategory ("/all" or "/category/xxx") once after data is loaded
                if (!_initialCategoryApplied &&
                    widget.initialCategory != null) {
                  int idx = 0;
                  if (widget.initialCategory == "All") {
                    idx = 0;
                  } else {
                    final catIndex = categories.indexWhere(
                      (c) => c.name == widget.initialCategory,
                    );
                    if (catIndex >= 0) {
                      idx = catIndex + 1;
                    }
                  }
                  _selectedTabIndex = idx;
                  _initialCategoryApplied = true;
                }

                // keep _selectedTabIndex in range even if categories changed
                final maxIndex = categories.length; // 0..N
                if (_selectedTabIndex > maxIndex) {
                  _selectedTabIndex = 0;
                }

                // determine which files to show based on selected tab (no titles/subtitles)
                List<SoundFile> visibleFiles;
                if (_selectedTabIndex == 0) {
                  visibleFiles = _sortedFiles(allFiles);
                } else {
                  final catIndex = _selectedTabIndex - 1;
                  final cat = categories[catIndex];
                  visibleFiles = _sortedFiles(cat.files);
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Center(child: logo),
                      const SizedBox(height: 12),
                      _navyCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.surround_sound, color: Colors.white),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Seamless soundscapes",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Self-recorded, infinitely loopable soundscapes. ",
                                style: TextStyle(
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text("All"),
                                    selected: _selectedTabIndex == 0,
                                    selectedColor: kAccent,
                                    backgroundColor: kNavySoft,
                                    showCheckmark: true,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: _selectedTabIndex == 0
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: _selectedTabIndex == 0
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedTabIndex = 0;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  for (var i = 0; i < categories.length; i++)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(categories[i].name),
                                        selected: _selectedTabIndex == i + 1,
                                        selectedColor: kAccent,
                                        backgroundColor: kNavySoft,
                                        showCheckmark: true,
                                        checkmarkColor: Colors.white,
                                        labelStyle: TextStyle(
                                          color: _selectedTabIndex == i + 1
                                              ? Colors.white
                                              : Colors.white70,
                                          fontWeight: _selectedTabIndex ==
                                                  i + 1
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedTabIndex = i + 1;
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: AudioGrid(files: visibleFiles),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
