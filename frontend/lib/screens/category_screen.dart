import 'package:flutter/material.dart';
import '../api_service.dart';
import '../widgets/audio_grid.dart';

class CategoryScreen extends StatefulWidget {
  final ApiService api;
  final String categoryName;

  const CategoryScreen({super.key, required this.api, required this.categoryName});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<SoundCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchCategories();
  }

  void _goBackToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed("/");
    }
  }

  void _goAll() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pushNamed("/all");
    } else {
      Navigator.of(context).pushReplacementNamed("/all");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // we provide our own leading/back
        leading: IconButton(
          tooltip: "Back",
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToDashboard,
        ),
        title: Text(widget.categoryName),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: "Dashboard",
            icon: const Icon(Icons.home),
            onPressed: _goBackToDashboard,
          ),
          IconButton(
            tooltip: "All Soundscapes",
            icon: const Icon(Icons.library_music),
            onPressed: _goAll,
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
                child: Text("Error: ${snap.error}", textAlign: TextAlign.center),
              ),
            );
          }
          final categories = snap.data ?? [];
          final matched = categories.where((c) => c.name == widget.categoryName).toList();
          if (matched.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Category not found or has no files yet.\nAdmins: open the Admin page to upload.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          final files = matched.first.files;
          if (files.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "This category is empty.\nAdmins: open the Admin page to upload.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: AudioGrid(files: files),
          );
        },
      ),
    );
  }
}
