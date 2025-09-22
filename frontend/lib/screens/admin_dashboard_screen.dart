import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ApiService api;
  const AdminDashboardScreen({super.key, required this.api});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<SoundCategory>> _future;
  String? _selectedCategory;
  final TextEditingController _newCategoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Do not redirect here; let the router decide. Only fetch when authed.
    if (widget.api.isAuthed) {
      _future = widget.api.fetchCategories();
    }
  }

  Future<void> _refresh() async {
    debugPrint("AdminDashboard: refreshing categories");
    setState(() {
      _future = widget.api.fetchCategories();
    });
  }

  Future<void> _logout() async {
    debugPrint("AdminDashboard: logging out");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    widget.api.setAuthToken(null);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/admin/login");
  }

  Future<void> _createCategory() async {
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      debugPrint("AdminDashboard: createCategory('$name')");
      await widget.api.createCategory(name);
      _newCategoryCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Created '$name'")));
      await _refresh();
    } catch (e) {
      debugPrint("AdminDashboard: createCategory error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Create failed: $e")));
      if (e.toString().contains("401")) {
        Navigator.pushReplacementNamed(context, "/admin/login");
      }
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedCategory == null) return;
    try {
      debugPrint("AdminDashboard: picking files for category '${_selectedCategory!}'");
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
      );
      if (result == null) return;
      for (final f in result.files) {
        final Uint8List? bytes = f.bytes;
        final name = f.name;
        if (bytes == null) continue;
        debugPrint("AdminDashboard: uploading '$name' to '${_selectedCategory!}'");
        await widget.api.uploadFile(category: _selectedCategory!, filename: name, bytes: bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload complete")));
      await _refresh();
    } catch (e) {
      debugPrint("AdminDashboard: upload error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      if (e.toString().contains("401")) {
        Navigator.pushReplacementNamed(context, "/admin/login");
      }
    }
  }

  Future<void> _promptRenameCategory(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Rename Category"),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "New name"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Rename")),
          ],
        );
      },
    );
    if (ok == true) {
      final newName = ctrl.text.trim();
      if (newName.isNotEmpty && newName != oldName) {
        try {
          debugPrint("AdminDashboard: renameCategory '$oldName' -> '$newName'");
          await widget.api.renameCategory(oldName, newName);
          if (_selectedCategory == oldName) _selectedCategory = newName;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Renamed '$oldName' -> '$newName'")));
          await _refresh();
        } catch (e) {
          debugPrint("AdminDashboard: renameCategory error: $e");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rename failed: $e")));
          if (e.toString().contains("401")) {
            Navigator.pushReplacementNamed(context, "/admin/login");
          }
        }
      }
    }
  }

  Future<void> _confirmDeleteCategory(String name) async {
    bool force = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSB) {
          return AlertDialog(
            title: const Text("Delete Category"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Delete '$name'?"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: force,
                      onChanged: (v) => setSB(() => force = v ?? true),
                    ),
                    const Expanded(child: Text("Force delete (also remove contained files)")),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
            ],
          );
        });
      },
    );
    if (ok == true) {
      try {
        debugPrint("AdminDashboard: deleteCategory '$name' force=$force");
        await widget.api.deleteCategory(name, force: force);
        if (_selectedCategory == name) _selectedCategory = null;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted '$name'")));
        await _refresh();
      } catch (e) {
        debugPrint("AdminDashboard: deleteCategory error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
        if (e.toString().contains("401")) {
          Navigator.pushReplacementNamed(context, "/admin/login");
        }
      }
    }
  }

  Future<void> _promptRenameFile(String category, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Rename File"),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "New filename (with extension)"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Rename")),
          ],
        );
      },
    );
    if (ok == true) {
      final newName = ctrl.text.trim();
      if (newName.isNotEmpty && newName != oldName) {
        try {
          debugPrint("AdminDashboard: renameFile '$oldName' -> '$newName' in '$category'");
          await widget.api.renameFile(category: category, oldName: oldName, newName: newName);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Renamed '$oldName' -> '$newName'")));
          await _refresh();
        } catch (e) {
          debugPrint("AdminDashboard: renameFile error: $e");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rename failed: $e")));
          if (e.toString().contains("401")) {
            Navigator.pushReplacementNamed(context, "/admin/login");
          }
        }
      }
    }
  }

  Future<void> _confirmDeleteFile(String category, String filename) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Delete File"),
          content: Text("Delete '$filename' from '$category'?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
          ],
        );
      },
    );
    if (ok == true) {
      try {
        debugPrint("AdminDashboard: deleteFile '$filename' from '$category'");
        await widget.api.deleteFile(category: category, filename: filename);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted '$filename'")));
        await _refresh();
      } catch (e) {
        debugPrint("AdminDashboard: deleteFile error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
        if (e.toString().contains("401")) {
          Navigator.pushReplacementNamed(context, "/admin/login");
        }
      }
    }
  }

  Future<void> _promptMoveFile(String category, String filename, List<String> categories) async {
    String target = category;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSB) {
          return AlertDialog(
            title: const Text("Move File"),
            content: DropdownButtonFormField<String>(
              value: target,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setSB(() => target = v ?? category),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Target category"),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Move")),
            ],
          );
        });
      },
    );
    if (ok == true && target != category) {
      try {
        debugPrint("AdminDashboard: moveFile '$filename' $category -> $target");
        await widget.api.moveFile(oldCategory: category, filename: filename, newCategory: target);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved to '$target'")));
        await _refresh();
      } catch (e) {
        debugPrint("AdminDashboard: moveFile error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Move failed: $e")));
        if (e.toString().contains("401")) {
          Navigator.pushReplacementNamed(context, "/admin/login");
        }
      }
    }
  }

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If user reaches this screen unauthenticated, show a clear message and a way to go to login,
    // instead of redirecting in initState (which can create loops on web).
    if (!widget.api.isAuthed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Admin"),
          centerTitle: true,
          backgroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Admin session required.\nPlease sign in to continue.",
                  textAlign: TextAlign.center,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, "/admin/login"),
                child: const Text("Go to Login"),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<SoundCategory>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Admin"),
              centerTitle: true,
              backgroundColor: Colors.black,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Error: ${snap.error}", textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final categories = snap.data ?? [];
        final names = categories.map((e) => e.name).toList();
        _selectedCategory ??= names.isNotEmpty ? names.first : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Admin"),
            centerTitle: true,
            backgroundColor: Colors.black,
            actions: [
              IconButton(onPressed: _refresh, tooltip: "Refresh", icon: const Icon(Icons.refresh)),
              IconButton(onPressed: _logout, tooltip: "Logout", icon: const Icon(Icons.logout)),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: names.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        decoration: const InputDecoration(
                          labelText: "Selected category",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: names.isEmpty ? null : _uploadFiles,
                        icon: const Icon(Icons.file_upload),
                        label: const Text("Upload"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryCtrl,
                        decoration: const InputDecoration(
                          labelText: "New category name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _createCategory,
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text("Create"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      return Card(
                        color: const Color(0xFF121212),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: "Rename category",
                                icon: const Icon(Icons.drive_file_rename_outline),
                                onPressed: () => _promptRenameCategory(cat.name),
                              ),
                              IconButton(
                                tooltip: "Delete category",
                                icon: const Icon(Icons.delete_forever),
                                onPressed: () => _confirmDeleteCategory(cat.name),
                              ),
                            ],
                          ),
                          children: [
                            if (cat.files.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("No files in this category."),
                                ),
                              ),
                            for (final f in cat.files)
                              ListTile(
                                title: Text(f.name),
                                subtitle: Text(f.url),
                                dense: true,
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      tooltip: "Move file",
                                      icon: const Icon(Icons.drive_file_move),
                                      onPressed: () => _promptMoveFile(cat.name, f.name, names),
                                    ),
                                    IconButton(
                                      tooltip: "Rename file",
                                      icon: const Icon(Icons.drive_file_rename_outline),
                                      onPressed: () => _promptRenameFile(cat.name, f.name),
                                    ),
                                    IconButton(
                                      tooltip: "Delete file",
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _confirmDeleteFile(cat.name, f.name),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
