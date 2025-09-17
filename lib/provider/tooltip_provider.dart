import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TooltipProvider extends ChangeNotifier {
  static const String _prefsKey = 'show_info_tooltips';
  bool _showTooltips = true;

  bool get showTooltips => _showTooltips;

  TooltipProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _showTooltips = prefs.getBool(_prefsKey) ?? true;
    notifyListeners();
  }

  Future<void> setShowTooltips(bool value) async {
    _showTooltips = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    notifyListeners();
  }
}