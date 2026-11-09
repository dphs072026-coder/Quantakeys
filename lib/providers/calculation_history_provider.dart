import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class CalculationHistoryProvider with ChangeNotifier {
  List<HistoryItem> _items = [];

  List<HistoryItem> get items => _items;

  CalculationHistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Ensure we have the latest history from disk
      final String? historyJson = prefs.getString('calculation_history');
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        _items = decoded.map((item) => HistoryItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  Future<void> addEntry(String input, String result) async {
    final newItem = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      input: input,
      result: result,
      timestamp: DateTime.now(),
    );
    _items.insert(0, newItem);
    
    // Keep only last 100 entries for performance
    if (_items.length > 100) {
      _items = _items.sublist(0, 100);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calculation_history', json.encode(_items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _items = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('calculation_history');
    notifyListeners();
  }
}
