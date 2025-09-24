import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeekStartDay {
  sunday,
  monday
}

class FirstDayOfWeekProvider extends ChangeNotifier {
  WeekStartDay _firstDayOfWeek = WeekStartDay.monday; // Default to Monday

  FirstDayOfWeekProvider() {
    _loadFirstDayOfWeek();
  }

  WeekStartDay get firstDayOfWeek => _firstDayOfWeek;

  /// Returns the MaterialLocalizations first day of week value (1-7, where 1 is Sunday)
  int get materialFirstDayOfWeek {
    return _firstDayOfWeek == WeekStartDay.sunday ? DateTime.sunday : DateTime.monday;
  }

  Future<void> _loadFirstDayOfWeek() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? dayString = prefs.getString('firstDayOfWeek');
    if (dayString == 'sunday') {
      _firstDayOfWeek = WeekStartDay.sunday;
    } else {
      _firstDayOfWeek = WeekStartDay.monday;
    }
    notifyListeners();
  }

  Future<void> setFirstDayOfWeek(WeekStartDay day) async {
    _firstDayOfWeek = day;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (day == WeekStartDay.sunday) {
      prefs.setString('firstDayOfWeek', 'sunday');
    } else {
      prefs.setString('firstDayOfWeek', 'monday');
    }
  }
}