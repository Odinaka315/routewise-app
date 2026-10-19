# Routewise (Flutter)

Flutter port of the "App Design Specifications" Figma Make project: a delivery
route planner for Lagos riders. Phone layout plus a wide layout (sidebar,
two-column planner, split route result) from 900 px up.

## Run it

This archive contains only the Dart code, not the Android/iOS/web folders.

```bash
flutter create routewise --org com.example   # generates android/, ios/, web/ ...
cd routewise
# copy this archive's lib/, test/, pubspec.yaml, analysis_options.yaml over the new project
flutter pub get
flutter run
```

If `flutter create` generated `test/widget_test.dart`, replace it with the one
from this archive (the generated one references the default counter app).

Fonts (DM Sans, Manrope) are fetched at runtime by `google_fonts`, so the first
launch needs internet. To work offline, download the fonts, declare them in
`pubspec.yaml`, and set `GoogleFonts.config.allowRuntimeFetching = false`.

## Screens

| Screen | File |
| --- | --- |
| Log in / Sign up / Check email / Forgot password | `lib/screens/auth_screen.dart` |
| Shell (sidebar or bottom nav) | `lib/screens/app_shell.dart` |
| Trips (stats, starred, search, filter) | `lib/screens/trips_screen.dart` |
| Plan a route / Edit a copy (drag to reorder stops) | `lib/screens/plan_screen.dart` |
| Calculating animation | `lib/screens/calculating_view.dart` |
| Route result | `lib/screens/route_screen.dart` |
| Run history | `lib/screens/history_screen.dart` |
| Profile & settings (dark mode, defaults, log out) | `lib/screens/profile_screen.dart` |

Design tokens (colours, light and dark) are in `lib/theme/app_colors.dart`.
Text styles are in `lib/theme/app_theme.dart`.

## What is real and what is a placeholder

The Figma project is UI only, so this is too:

- **Sign-in is mocked.** Any input logs you in. Connect your auth service in
  `AppState.login / logout` (`lib/state/app_state.dart`).
- **Trips and route results are demo data** (`lib/data/sample_data.dart`). The
  planner does not optimise anything: it keeps your stop order and shows the
  design's example distance / time / "24% shorter". Call your routing API in
  `_calculate()` in `plan_screen.dart`.
- **Maps are illustrations**, painted from the design's SVG paths, not a real
  map. Swap `MiniMap` / `ResultMap` (`lib/widgets/map_views.dart`) for
  `google_maps_flutter` or `flutter_map`.
- **Add a stop** inserts a sample address. Replace `_addStop()` with address
  search / geocoding, drop-a-pin, GPS and paste-addresses.
- Buttons without a backend (Start navigation, trip actions, edit profile)
  show a "coming soon" message. The distance-units setting is stored but not
  applied.
- State uses a plain `ChangeNotifier`, with no extra packages. Move to
  Riverpod / Bloc / Provider if you prefer.

## Small differences from the design

- The design hides the "remove stop" button on phones. This version hides the
  "more" button instead, so stops can still be removed.
- Date and greeting on the Trips screen use the real current time.
- The map and the options block on the planner stay in the design's order
  (map below the form on phones).

## Maps, address search and navigation

- **Map**: `flutter_map` with OpenStreetMap / CARTO tiles by default (free, light use only). For a public release build with a Mapbox **public** token so tiles come from Mapbox:
  `flutter run --dart-define=MAPBOX_TOKEN=pk.your-token` (also works for `flutter build apk`).
- **Address search** is done by the backend. Nominatim (the default) knows few Lagos house numbers. In Render set `GEOCODER_PROVIDER=mapbox` and `MAPBOX_ACCESS_TOKEN=sk.or.pk...` for better results. When search finds nothing, riders can add the address as typed or drop a pin.
- **Navigation**: "Start navigation" steps through the stops and opens Google Maps or Waze for turn-by-turn directions to the next one.
- **Android/iOS permissions**: location (for "My location") is declared in `AndroidManifest.xml` and `Info.plist`.
- "Edit profile" needs backend PR `PATCH /auth/me`.
