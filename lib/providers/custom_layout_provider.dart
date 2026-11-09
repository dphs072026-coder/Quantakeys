import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/key_layout.dart';
import '../services/cloud_sync_service.dart';

class CustomLayoutProvider with ChangeNotifier {
  List<KeyLayout> _customLayouts = [];
  Set<String> _deletedLayoutNames = {};
  final CloudSyncService _cloudSync = CloudSyncService();

  List<KeyLayout> get customLayouts => _customLayouts;
  bool get isSignedIn => _cloudSync.isSignedIn;

  CustomLayoutProvider() {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Force reload from disk
      
      final List<String> deletedList = prefs.getStringList('deleted_custom_layouts') ?? [];
      _deletedLayoutNames = deletedList.toSet();

      final String? layoutsJson = prefs.getString('custom_layouts');
      if (layoutsJson != null && layoutsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(layoutsJson);
        _customLayouts = decoded.map((item) => KeyLayout.fromJson(item)).toList();
      } else {
        _customLayouts = [];
      }
      notifyListeners();

      // If signed in, sync cloud layouts non-blockingly in background
      if (_cloudSync.isSignedIn) {
        Future.microtask(() => syncWithCloud());
      }
    } catch (e) {
      debugPrint("Error refreshing custom layouts: $e");
    }
  }

  Future<void> addLayout(KeyLayout layout) async {
    _deletedLayoutNames.remove(layout.name);
    _customLayouts.removeWhere((l) => l.name == layout.name);
    _customLayouts.add(layout);
    await _save();
    notifyListeners();
  }

  Future<void> removeLayout(String name) async {
    _customLayouts.removeWhere((l) => l.name == name);
    _deletedLayoutNames.add(name);
    if (_cloudSync.isSignedIn) {
      Future.microtask(() => _cloudSync.deleteCloudLayout(name));
    }
    await _save();
    notifyListeners();
  }

  Future<void> syncWithCloud() async {
    if (!_cloudSync.isSignedIn) return;
    try {
      // 1. Download cloud layouts first
      final cloudLayouts = await _cloudSync.downloadLayouts();

      // 2. Merge cloud and local layouts into a unified map
      final Map<String, KeyLayout> merged = {};
      
      // Add cloud layouts that haven't been deleted locally
      for (var l in cloudLayouts) {
        if (!_deletedLayoutNames.contains(l.name)) {
          merged[l.name] = l;
        }
      }

      // Add local layouts
      for (var l in _customLayouts) {
        if (!_deletedLayoutNames.contains(l.name)) {
          merged[l.name] = l;
        }
      }

      _customLayouts = merged.values.toList();
      await _save();
      
      // 3. Upload unified list to cloud
      await _cloudSync.uploadLayouts(_customLayouts);
      notifyListeners();
    } catch (e) {
      debugPrint("Cloud sync error: $e");
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutsJson = json.encode(_customLayouts.map((e) => e.toJson()).toList());
    await prefs.setString('custom_layouts', layoutsJson);
    await prefs.setStringList('deleted_custom_layouts', _deletedLayoutNames.toList());
    try {
      const MethodChannel('com.quantakeys/ime').invokeMethod('notifySettingsChanged', {
        'custom_layouts': layoutsJson,
      });
    } catch (_) {}
    if (_cloudSync.isSignedIn) {
      // Background upload
      Future.microtask(() => _cloudSync.uploadLayouts(_customLayouts));
    }
  }
}
