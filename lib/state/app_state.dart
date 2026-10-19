import 'package:flutter/material.dart';

import '../data/api_models.dart';
import '../data/models.dart';
import '../services/api_service.dart';

/// App-wide state (auth, theme, preferences and trips).
/// 
/// Fully integrated with the live Routewise backend hosted on Render.
class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  ThemeMode _themeMode = ThemeMode.light;
  String _userName = 'Rider';
  String _userEmail = '';
  bool _emailVerified = false;
  List<Trip> _trips = [];
  bool _isLoadingTrips = false;

  /// 0 = Fastest, 1 = Balanced, 2 = Shortest.
  int defaultOptimise = 1;

  /// 0 = One-way, 1 = Return to start.
  int defaultRouteType = 0;

  /// 0 = Kilometres, 1 = Miles (label only for now).
  int distanceUnit = 0;

  bool get isAuthenticated => _isAuthenticated;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  String get userName => _userName;
  String get userEmail => _userEmail;
  bool get isEmailVerified => _emailVerified;
  bool get isLoadingTrips => _isLoadingTrips;

  String get firstName => _userName.isNotEmpty ? _userName.split(' ').first : 'Rider';
  String get initials {
    if (_userName.isEmpty) return 'R';
    final parts = _userName.split(' ').where((part) => part.isNotEmpty).take(2);
    if (parts.isEmpty) return 'R';
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  List<Trip> get trips => List<Trip>.unmodifiable(_trips);
  List<Trip> get starredTrips => _trips.where((t) => t.starred).toList();

  int get routesThisMonth {
    final now = DateTime.now();
    return _trips.where((t) {
      if (t.createdAt == null) return true;
      return t.createdAt!.year == now.year && t.createdAt!.month == now.month;
    }).length;
  }

  double get totalDistancePlannedKm {
    double total = 0;
    for (final t in _trips) {
      if (t.distanceM != null) total += (t.distanceM! / 1000);
    }
    return total;
  }

  double get totalTimeHours {
    double total = 0;
    for (final t in _trips) {
      if (t.durationS != null) total += (t.durationS! / 3600);
    }
    return total;
  }

  String get routesThisMonthText => '$routesThisMonth';
  String get totalDistancePlannedText => '${totalDistancePlannedKm.toStringAsFixed(1)} km';
  String get totalTimePlannedText => '${totalTimeHours.toStringAsFixed(1)} hrs';

  /// Initializes authentication state and fetches real user & trips from the backend.
  Future<void> init() async {
    await ApiService.instance.init();
    if (ApiService.instance.isAuthenticated) {
      _isAuthenticated = true;
      final user = ApiService.instance.currentUser;
      if (user != null) {
        _userEmail = user.email;
        _userName = user.displayName ?? user.email.split('@').first;
        _emailVerified = user.emailVerified;
      }
      notifyListeners();

      // Refresh user details and trips in background
      try {
        final freshUser = await ApiService.instance.getMe();
        _userEmail = freshUser.email;
        _userName = freshUser.displayName ?? freshUser.email.split('@').first;
        _emailVerified = freshUser.emailVerified;
      } catch (_) {}

      await refreshTrips();
    }
  }

  /// Real backend login.
  Future<void> login({required String email, String password = ''}) async {
    if (password.isNotEmpty) {
      await ApiService.instance.login(email: email, password: password);
    }
    _isAuthenticated = true;
    _userEmail = email.trim();
    final user = ApiService.instance.currentUser;
    if (user != null) {
      _userEmail = user.email;
      _userName = user.displayName ?? user.email.split('@').first;
      _emailVerified = user.emailVerified;
    }
    notifyListeners();
    if (password.isNotEmpty) {
      await refreshTrips();
    }
  }

  /// Real backend signup.
  Future<void> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = await ApiService.instance.signup(
      email: email,
      password: password,
      displayName: displayName,
    );
    _userEmail = user.email;
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _userName = user.displayName!;
    }
    notifyListeners();
  }

  /// Real backend logout (current device).
  Future<void> logout() async {
    _isAuthenticated = false;
    _trips = [];
    notifyListeners();
    try {
      await ApiService.instance.logout();
    } catch (_) {}
  }

  /// Real backend logout (all devices).
  Future<void> logoutAll() async {
    _isAuthenticated = false;
    _trips = [];
    notifyListeners();
    try {
      await ApiService.instance.logoutAll();
    } catch (_) {}
  }

  /// Resend verification email.
  Future<String> resendVerification({required String email}) async {
    return ApiService.instance.resendVerification(email: email);
  }

  /// Forgot password.
  Future<String> forgotPassword({required String email}) async {
    return ApiService.instance.forgotPassword(email: email);
  }

  /// Fetches saved trips from the live backend.
  Future<void> refreshTrips() async {
    if (!_isAuthenticated) return;
    _isLoadingTrips = true;
    notifyListeners();

    try {
      final res = await ApiService.instance.listTrips();
      final items = res['items'] as List<dynamic>? ?? [];
      final serverTrips = <Trip>[];

      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? '';
          final title = item['title']?.toString() ?? 'Trip';
          final isStarred = item['is_starred'] as bool? ?? false;
          final stopCount = (item['stop_count'] as num?)?.toInt() ?? 0;
          final distM = (item['total_distance_m'] as num?)?.toDouble();
          final durS = (item['total_duration_s'] as num?)?.toDouble();
          final createdAt = item['created_at']?.toString() ?? '';
          final runStatus = (item['latest_run'] as Map?)?['status'] as String?;

          String distStr = '0 km';
          if (distM != null) {
            distStr = '${(distM / 1000).toStringAsFixed(1)} km';
          }

          String timeStr = '0 min';
          if (durS != null) {
            final mins = (durS / 60).round();
            if (mins >= 60) {
              final h = mins ~/ 60;
              final m = mins % 60;
              timeStr = '$h hr ${m > 0 ? '$m min' : ''}'.trim();
            } else {
              timeStr = '$mins min';
            }
          }

          DateTime? dt;
          String dateStr = 'Recently';
          if (createdAt.isNotEmpty) {
            dt = DateTime.tryParse(createdAt);
            if (dt != null) {
              final now = DateTime.now();
              final diff = now.difference(dt);
              if (diff.inMinutes < 60) {
                dateStr = 'Just now';
              } else if (diff.inHours < 24) {
                dateStr = '${diff.inHours}h ago';
              } else {
                dateStr = '${dt.day}/${dt.month}/${dt.year}';
              }
            }
          }

          serverTrips.add(
            Trip(
              id: id,
              title: title,
              stops: stopCount,
              distance: distStr,
              time: timeStr,
              date: dateStr,
              starred: isStarred,
              failed: runStatus == 'failed',
              calculating: runStatus == 'queued' || runStatus == 'running',
              distanceM: distM,
              durationS: durS,
              createdAt: dt,
            ),
          );
        }
      }

      _trips = serverTrips;
    } catch (_) {
      // If error occurs or no trips exist yet, leave existing state
    } finally {
      _isLoadingTrips = false;
      notifyListeners();
    }
  }

  Future<void> toggleStar(String id) async {
    final idx = _trips.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final target = _trips[idx];
    final nextStar = !target.starred;

    // Optimistic UI update
    _trips = [
      for (final trip in _trips)
        if (trip.id == id) trip.copyWith(starred: nextStar) else trip,
    ];
    notifyListeners();

    if (_isAuthenticated) {
      try {
        await ApiService.instance.patchTrip(id, isStarred: nextStar);
      } catch (_) {
        // Rollback on error
        _trips = [
          for (final trip in _trips)
            if (trip.id == id) trip.copyWith(starred: !nextStar) else trip,
        ];
        notifyListeners();
      }
    }
  }

  /// Rename a trip on the server, then reload the list.
  Future<void> renameTrip(String id, String title) async {
    await ApiService.instance.patchTrip(id, title: title);
    await refreshTrips();
  }

  /// Delete a trip on the server and drop it from the list.
  Future<void> deleteTrip(String id) async {
    await ApiService.instance.deleteTrip(id);
    _trips = _trips.where((t) => t.id != id).toList();
    notifyListeners();
  }

  /// Run a trip's calculation again (used by "Try again" on a failed trip).
  Future<void> retryTrip(String id) async {
    try {
      await ApiService.instance.recalculateTrip(id);
    } on ApiException catch (e) {
      if (e.statusCode != 409) rethrow; // 409: already being calculated
    }
    await refreshTrips();
  }

  /// Change the display name on the server.
  Future<void> updateDisplayName(String name) async {
    final user = await ApiService.instance.updateProfile(displayName: name);
    _userName = user.displayName ?? user.email.split('@').first;
    notifyListeners();
  }

  void addTrip(Trip trip) {
    _trips = [trip, ..._trips];
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
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
