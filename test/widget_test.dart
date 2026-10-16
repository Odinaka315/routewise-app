import 'package:flutter_test/flutter_test.dart';
import 'package:routewise/data/models.dart';
import 'package:routewise/state/app_state.dart';

void main() {
  test('toggleStar flips the starred flag and updates starredTrips', () {
    final state = AppState();
    expect(state.trips.firstWhere((t) => t.id == 't3').starred, isFalse);
    expect(state.starredTrips.length, 2);

    state.toggleStar('t3');

    expect(state.trips.firstWhere((t) => t.id == 't3').starred, isTrue);
    expect(state.starredTrips.length, 3);
  });

  test('login and logout change the authentication state', () {
    final state = AppState();
    expect(state.isAuthenticated, isFalse);

    state.login(email: ' rider@example.com ');
    expect(state.isAuthenticated, isTrue);
    expect(state.userEmail, 'rider@example.com');

    state.logout();
    expect(state.isAuthenticated, isFalse);
  });

  test('addTrip puts the new trip first and dark mode toggles', () {
    final state = AppState();
    state.addTrip(const Trip(
      id: 'new',
      title: 'New trip',
      stops: 3,
      distance: '10 km',
      time: '30 min',
      date: 'Just now',
    ));
    expect(state.trips.first.id, 'new');

    state.setDarkMode(true);
    expect(state.isDark, isTrue);
  });

  test('initials come from the user name', () {
    expect(AppState().initials, 'OA');
  });
}
