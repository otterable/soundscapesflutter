import 'package:flutter/material.dart';
import '../api_service.dart';
import '../widgets/audio_grid.dart';

class AllFilesScreen extends StatefulWidget {
  final ApiService api;
  const AllFilesScreen({super.key, required this.api});

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  late Future<List<SoundFile>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchAllFiles();
  }

  void _goBackToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed("/");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: "Back",
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToDashboard,
        ),
        title: const Text("All Soundscapes"),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: "Dashboard",
            icon: const Icon(Icons.home),
            onPressed: _goBackToDashboard,
          ),
        ],
      ),
      body: FutureBuilder<List<SoundFile>>(
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
          final files = snap.data ?? [];
          if (files.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No soundscapes on the server.\nAdmins: open the Admin page to create a category and upload files.",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: AudioGrid(files: files),
          );
        },
      ),
    );
  }
}
