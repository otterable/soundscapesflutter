// lib/screens/admin_dashboard_screen.dart

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

// brand palette
const Color kNavy = Color(0xFF003056);
const Color kNavySoft = Color(0xFF00213C);
const Color kAccent = Color(0xFFFF5C00);
const Color kDanger = Color(0xFF9A031E);
const Color kFieldBorder = Color(0xFF1E3C57);
const Color kOk = Color(0xFF1C5434);
const Color kRulesBeige = Color(0xFFF5E9DA);
const Color kErrorVivid = Color(0xFFEF233C);

// dialog helpers (mirroring fitness tracker popups)
const double _dlgTitleFontSize = 18.0;
const double _dlgVGap = 12.0;

const EdgeInsets _dlgInset = EdgeInsets.symmetric(horizontal: 16, vertical: 24);
const EdgeInsets _dlgContentPad = EdgeInsets.fromLTRB(16, _dlgVGap, 16, 0);
const EdgeInsets _dlgActionsPad = EdgeInsets.fromLTRB(16, _dlgVGap, 16, _dlgVGap);

const Size _dlgBtnMinSize = Size(112, 40);
const EdgeInsets _dlgBtnPad = EdgeInsets.symmetric(horizontal: 14, vertical: 10);

Row _dlgTitle(String text, {IconData icon = Icons.tune}) => Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: _dlgTitleFontSize,
            ),
          ),
        ),
      ],
    );

BoxConstraints _dialogConstraints(BuildContext ctx) {
  final size = MediaQuery.of(ctx).size;
  final maxW = (size.width * 0.9).clamp(320.0, 720.0);
  final maxH = (size.height * 0.8).clamp(320.0, 800.0);
  return BoxConstraints(maxWidth: maxW, maxHeight: maxH);
}

Widget _dlgActionRow({
  required BuildContext ctx,
  required String confirmText,
  required VoidCallback onConfirm,
  IconData confirmIcon = Icons.check,
  String cancelText = "Cancel",
  VoidCallback? onCancel,
  bool confirmEnabled = true,
  bool cancelEnabled = true,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kDanger,
          minimumSize: _dlgBtnMinSize,
          padding: _dlgBtnPad,
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.close, color: Colors.white),
        label: Text(
          cancelText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: cancelEnabled ? (onCancel ?? () => Navigator.of(ctx).pop(false)) : null,
      ),
      const SizedBox(width: 16),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kOk,
          minimumSize: _dlgBtnMinSize,
          padding: _dlgBtnPad,
          shape: const StadiumBorder(),
        ),
        icon: Icon(confirmIcon, color: Colors.white),
        label: Text(
          confirmText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: confirmEnabled ? onConfirm : null,
      ),
    ],
  );
}

InputDecoration _popupInputDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.bold,
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white),
      ),
      isDense: true,
      filled: true,
      fillColor: kNavySoft,
      hintStyle: const TextStyle(color: Colors.white54),
    );

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

  /// Cached categories so we can update the UI instantly after admin actions.
  List<SoundCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    if (widget.api.isAuthed) {
      _future = widget.api.fetchCategories();
    } else {
      _future = Future.value(<SoundCategory>[]);
    }
  }

  Future<void> _refresh() async {
    debugPrint("AdminDashboard: refreshing categories from server");
    setState(() {
      _categories = [];
      _future = widget.api.fetchCategories();
    });
  }

  Future<void> _logout() async {
    debugPrint("AdminDashboard: logging out");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    widget.api.setAuthToken(null);
    setState(() {
      _categories = [];
      _selectedCategory = null;
    });
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
      setState(() {
        final exists = _categories.any((c) => c.name == name);
        if (!exists) {
          final updated = List<SoundCategory>.from(_categories)
            ..add(SoundCategory(name: name, files: <SoundFile>[]));
          _categories = updated;
        }
        _selectedCategory ??= name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Created '$name'"),
        ),
      );
    } catch (e) {
      debugPrint("AdminDashboard: createCategory error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Create failed: $e"),
        ),
      );
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
        await widget.api.uploadFile(
          category: _selectedCategory!,
          filename: name,
          bytes: bytes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload complete")),
      );
      // Re-sync from server so we get the canonical filenames/URLs.
      await _refresh();
    } catch (e) {
      debugPrint("AdminDashboard: upload error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
      if (e.toString().contains("401")) {
        Navigator.pushReplacementNamed(context, "/admin/login");
      }
    }
  }

  Future<void> _promptRenameCategory(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final constraints = _dialogConstraints(ctx);
        return AlertDialog(
          backgroundColor: kNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: _dlgInset,
          contentPadding: _dlgContentPad,
          actionsPadding: _dlgActionsPad,
          actionsAlignment: MainAxisAlignment.center,
          title: _dlgTitle(
            "Rename category",
            icon: Icons.drive_file_rename_outline,
          ),
          content: ConstrainedBox(
            constraints: constraints,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Enter a new name for this category.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: _dlgVGap),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _popupInputDecoration("New name"),
                ),
              ],
            ),
          ),
          actions: [
            _dlgActionRow(
              ctx: ctx,
              confirmText: "Rename",
              confirmIcon: Icons.check,
              cancelText: "Cancel",
              onConfirm: () => Navigator.of(ctx).pop(true),
            ),
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
          if (!mounted) return;
          setState(() {
            final idx = _categories.indexWhere((c) => c.name == oldName);
            if (idx != -1) {
              final oldCat = _categories[idx];
              final updatedFiles = oldCat.files
                  .map(
                    (f) => SoundFile(
                      name: f.name,
                      url: widget.api.buildFileUrl(newName, f.name),
                    ),
                  )
                  .toList();
              _categories[idx] = SoundCategory(
                name: newName,
                files: updatedFiles,
              );
            }
            if (_selectedCategory == oldName) {
              _selectedCategory = newName;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Renamed '$oldName' -> '$newName'")),
          );
        } catch (e) {
          debugPrint("AdminDashboard: renameCategory error: $e");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Rename failed: $e")),
          );
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
      barrierDismissible: true,
      builder: (ctx) {
        final constraints = _dialogConstraints(ctx);
        return StatefulBuilder(
          builder: (ctx2, setSB) {
            return AlertDialog(
              backgroundColor: kNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: _dlgInset,
              contentPadding: _dlgContentPad,
              actionsPadding: _dlgActionsPad,
              actionsAlignment: MainAxisAlignment.center,
              title: _dlgTitle(
                "Delete category",
                icon: Icons.delete_forever,
              ),
              content: ConstrainedBox(
                constraints: constraints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Delete '$name'?",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: force,
                          activeColor: kAccent,
                          onChanged: (v) {
                            setSB(() => force = v ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            "Force delete (also remove contained files)",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                _dlgActionRow(
                  ctx: ctx,
                  confirmText: "Delete",
                  confirmIcon: Icons.delete_forever,
                  cancelText: "Cancel",
                  onConfirm: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      try {
        debugPrint("AdminDashboard: deleteCategory '$name' force=$force");
        await widget.api.deleteCategory(name, force: force);
        if (!mounted) return;
        setState(() {
          _categories = _categories.where((c) => c.name != name).toList();
          if (_selectedCategory == name) {
            _selectedCategory =
                _categories.isNotEmpty ? _categories.first.name : null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deleted '$name'")),
        );
      } catch (e) {
        debugPrint("AdminDashboard: deleteCategory error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e")),
        );
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
      barrierDismissible: true,
      builder: (ctx) {
        final constraints = _dialogConstraints(ctx);
        return AlertDialog(
          backgroundColor: kNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: _dlgInset,
          contentPadding: _dlgContentPad,
          actionsPadding: _dlgActionsPad,
          actionsAlignment: MainAxisAlignment.center,
          title: _dlgTitle(
            "Rename file",
            icon: Icons.drive_file_rename_outline,
          ),
          content: ConstrainedBox(
            constraints: constraints,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "New filename (with extension).",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: _dlgVGap),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _popupInputDecoration("New filename"),
                ),
              ],
            ),
          ),
          actions: [
            _dlgActionRow(
              ctx: ctx,
              confirmText: "Rename",
              confirmIcon: Icons.check,
              cancelText: "Cancel",
              onConfirm: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      final newName = ctrl.text.trim();
      if (newName.isNotEmpty && newName != oldName) {
        try {
          debugPrint("AdminDashboard: renameFile '$oldName' -> '$newName' in '$category'");
          await widget.api.renameFile(
            category: category,
            oldName: oldName,
            newName: newName,
          );
          if (!mounted) return;
          setState(() {
            final catIndex = _categories.indexWhere((c) => c.name == category);
            if (catIndex != -1) {
              final cat = _categories[catIndex];
              final files = List<SoundFile>.from(cat.files);
              final fileIndex = files.indexWhere((f) => f.name == oldName);
              if (fileIndex != -1) {
                files[fileIndex] = SoundFile(
                  name: newName,
                  url: widget.api.buildFileUrl(category, newName),
                );
                _categories[catIndex] = SoundCategory(
                  name: cat.name,
                  files: files,
                );
              }
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Renamed '$oldName' -> '$newName'")),
          );
        } catch (e) {
          debugPrint("AdminDashboard: renameFile error: $e");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Rename failed: $e")),
          );
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
      barrierDismissible: true,
      builder: (ctx) {
        final constraints = _dialogConstraints(ctx);
        return AlertDialog(
          backgroundColor: kNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: _dlgInset,
          contentPadding: _dlgContentPad,
          actionsPadding: _dlgActionsPad,
          actionsAlignment: MainAxisAlignment.center,
          title: _dlgTitle(
            "Delete file",
            icon: Icons.delete,
          ),
          content: ConstrainedBox(
            constraints: constraints,
            child: Text(
              "Delete '$filename' from '$category'?",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          actions: [
            _dlgActionRow(
              ctx: ctx,
              confirmText: "Delete",
              confirmIcon: Icons.delete,
              cancelText: "Cancel",
              onConfirm: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      try {
        debugPrint("AdminDashboard: deleteFile '$filename' from '$category'");
        await widget.api.deleteFile(
          category: category,
          filename: filename,
        );
        if (!mounted) return;
        setState(() {
          final catIndex = _categories.indexWhere((c) => c.name == category);
          if (catIndex != -1) {
            final cat = _categories[catIndex];
            final files = List<SoundFile>.from(cat.files)
              ..removeWhere((f) => f.name == filename);
            _categories[catIndex] = SoundCategory(
              name: cat.name,
              files: files,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deleted '$filename'")),
        );
      } catch (e) {
        debugPrint("AdminDashboard: deleteFile error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e")),
        );
        if (e.toString().contains("401")) {
          Navigator.pushReplacementNamed(context, "/admin/login");
        }
      }
    }
  }

  Future<void> _promptMoveFile(
    String category,
    String filename,
    List<String> categories,
  ) async {
    String target = category;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final constraints = _dialogConstraints(ctx);
        return StatefulBuilder(
          builder: (ctx2, setSB) {
            return AlertDialog(
              backgroundColor: kNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: _dlgInset,
              contentPadding: _dlgContentPad,
              actionsPadding: _dlgActionsPad,
              actionsAlignment: MainAxisAlignment.center,
              title: _dlgTitle(
                "Move file",
                icon: Icons.drive_file_move,
              ),
              content: ConstrainedBox(
                constraints: constraints,
                child: DropdownButtonFormField<String>(
                  value: target,
                  dropdownColor: kNavySoft,
                  iconEnabledColor: Colors.white,
                  decoration: _popupInputDecoration("Target category"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setSB(() => target = v ?? category);
                  },
                ),
              ),
              actions: [
                _dlgActionRow(
                  ctx: ctx,
                  confirmText: "Move",
                  confirmIcon: Icons.check,
                  cancelText: "Cancel",
                  onConfirm: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true && target != category) {
      try {
        debugPrint("AdminDashboard: moveFile '$filename' $category -> $target");
        await widget.api.moveFile(
          oldCategory: category,
          filename: filename,
          newCategory: target,
        );
        if (!mounted) return;
        setState(() {
          SoundFile? movedFile;
          final srcIndex = _categories.indexWhere((c) => c.name == category);
          if (srcIndex != -1) {
            final srcCat = _categories[srcIndex];
            final srcFiles = List<SoundFile>.from(srcCat.files);
            final fileIndex = srcFiles.indexWhere((f) => f.name == filename);
            if (fileIndex != -1) {
              movedFile = srcFiles.removeAt(fileIndex);
              _categories[srcIndex] = SoundCategory(
                name: srcCat.name,
                files: srcFiles,
              );
            }
          }
          if (movedFile != null) {
            final destUrl = widget.api.buildFileUrl(target, movedFile.name);
            final newFile = SoundFile(name: movedFile.name, url: destUrl);
            final dstIndex = _categories.indexWhere((c) => c.name == target);
            if (dstIndex != -1) {
              final destCat = _categories[dstIndex];
              final destFiles = List<SoundFile>.from(destCat.files)..add(newFile);
              _categories[dstIndex] = SoundCategory(
                name: destCat.name,
                files: destFiles,
              );
            } else {
              final updated = List<SoundCategory>.from(_categories)
                ..add(SoundCategory(name: target, files: <SoundFile>[newFile]));
              _categories = updated;
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Moved to '$target'")),
        );
      } catch (e) {
        debugPrint("AdminDashboard: moveFile error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Move failed: $e")),
        );
        if (e.toString().contains("401")) {
          Navigator.pushReplacementNamed(context, "/admin/login");
        }
      }
    }
  }

  Widget _navyCard({required Widget child}) {
    return Card(
      color: kNavy.withOpacity(0.92),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.api.isAuthed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Admin"),
          centerTitle: true,
          backgroundColor: kNavy.withOpacity(0.95),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/molen.png',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withOpacity(0.30)),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _navyCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.white),
                      const SizedBox(height: 8),
                      const Text(
                        "Admin session required",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please sign in to continue to the admin dashboard.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, "/admin/login"),
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: const Text(
                          "Go to login",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin"),
        centerTitle: true,
        backgroundColor: kNavy.withOpacity(0.95),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
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
          Container(color: Colors.black.withOpacity(0.30)),
          SafeArea(
            child: FutureBuilder<List<SoundCategory>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _categories.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snap.hasError && _categories.isEmpty) {
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
                                  "Error loading categories",
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

                if (snap.hasData && _categories.isEmpty) {
                  _categories = snap.data ?? <SoundCategory>[];
                }

                final categories = _categories;
                final names = categories.map((e) => e.name).toList();

                if (_selectedCategory == null && names.isNotEmpty) {
                  _selectedCategory = names.first;
                } else if (_selectedCategory != null &&
                    !names.contains(_selectedCategory)) {
                  _selectedCategory =
                      names.isNotEmpty ? names.first : null;
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      _navyCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.library_music, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Categories & uploads",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Select a category to upload new soundscapes. "
                              "You can rename or delete categories below.",
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    items: names
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedCategory = v),
                                    dropdownColor: kNavySoft,
                                    iconEnabledColor: Colors.white,
                                    decoration: const InputDecoration(
                                      labelText: "Selected category",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: names.isEmpty ? null : _uploadFiles,
                                    icon: const Icon(Icons.file_upload,
                                        color: Colors.white),
                                    label: const Text(
                                      "Upload files",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _navyCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.create_new_folder,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Create new category",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Create a new category to group related soundscapes.",
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _newCategoryCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "New category name",
                                prefixIcon: Icon(
                                  Icons.label_outline,
                                  color: Colors.white70,
                                ),
                              ),
                              onSubmitted: (_) => _createCategory(),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _createCategory,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text(
                                  "Create",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _navyCard(
                          child: categories.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No categories yet. Create one above to begin.",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: categories.length,
                                  itemBuilder: (context, i) {
                                    final cat = categories[i];
                                    return Card(
                                      color: kNavySoft,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: ExpansionTile(
                                        iconColor: Colors.white70,
                                        collapsedIconColor: Colors.white70,
                                        title: Text(
                                          cat.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              tooltip: "Rename category",
                                              icon: const Icon(
                                                Icons.drive_file_rename_outline,
                                                color: Colors.white70,
                                              ),
                                              onPressed: () =>
                                                  _promptRenameCategory(cat.name),
                                            ),
                                            IconButton(
                                              tooltip: "Delete category",
                                              icon: const Icon(
                                                Icons.delete_forever,
                                                color: kDanger,
                                              ),
                                              onPressed: () =>
                                                  _confirmDeleteCategory(cat.name),
                                            ),
                                          ],
                                        ),
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                        children: [
                                          if (cat.files.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  "No files in this category.",
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          for (final f in cat.files)
                                            ListTile(
                                              title: Text(
                                                f.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                f.url,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              dense: true,
                                              trailing: Wrap(
                                                spacing: 4,
                                                children: [
                                                  IconButton(
                                                    tooltip: "Move file",
                                                    icon: const Icon(
                                                      Icons.drive_file_move,
                                                      color: Colors.white70,
                                                    ),
                                                    onPressed: () =>
                                                        _promptMoveFile(
                                                      cat.name,
                                                      f.name,
                                                      names,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: "Rename file",
                                                    icon: const Icon(
                                                      Icons.drive_file_rename_outline,
                                                      color: Colors.white70,
                                                    ),
                                                    onPressed: () =>
                                                        _promptRenameFile(
                                                      cat.name,
                                                      f.name,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: "Delete file",
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: kDanger,
                                                    ),
                                                    onPressed: () =>
                                                        _confirmDeleteFile(
                                                      cat.name,
                                                      f.name,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
                                    );
                                  },
                                ),
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
