import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';

/// App-wide state (auth, theme, preferences and trips).
///
/// Kept deliberately simple (ChangeNotifier + a global instance) so the UI
/// port has no extra dependencies. Swap for Provider / Riverpod / Bloc and
/// real services when you add a backend.
class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  ThemeMode _themeMode = ThemeMode.light;
  String _userName = 'Ola Adebayo';
  String _userEmail = 'ola@dispatch.ng';
  List<Trip> _trips = List<Trip>.of(sampleTrips);

  /// 0 = Fastest, 1 = Balanced, 2 = Shortest.
  int defaultOptimise = 1;

  /// 0 = One-way, 1 = Return to start.
  int defaultRouteType = 0;

  /// 0 = Kilometres, 1 = Miles (label only for now, no conversion yet).
  int distanceUnit = 0;

  bool get isAuthenticated => _isAuthenticated;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get firstName => _userName.split(' ').first;
  String get initials => _userName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  List<Trip> get trips => List<Trip>.unmodifiable(_trips);
  List<Trip> get starredTrips => _trips.where((t) => t.starred).toList();

  void login({String? email}) {
    if (email != null && email.trim().isNotEmpty) {
      _userEmail = email.trim();
    }
    _isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleStar(String id) {
    _trips = [
      for (final trip in _trips)
        if (trip.id == id) trip.copyWith(starred: !trip.starred) else trip,
    ];
    notifyListeners();
  }

  void addTrip(Trip trip) {
    _trips = [trip, ..._trips];
    notifyListeners();
  }

  void setDefaultOptimise(int index) {
    defaultOptimise = index;
    notifyListeners();
  }

  void setDefaultRouteType(int index) {
    defaultRouteType = index;
    notifyListeners();
  }

  void setDistanceUnit(int index) {
    distanceUnit = index;
    notifyListeners();
  }
}

final AppState appState = AppState();
