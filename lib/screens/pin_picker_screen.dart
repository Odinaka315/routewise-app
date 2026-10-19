import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../data/api_models.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/map_views.dart';
import '../widgets/route_map.dart';

/// Full-screen map where the rider moves the map under a fixed pin to choose
/// an exact spot. Pops with a [GeocodeResult] (source "manual_pin"), or null if
/// the rider goes back.
///
/// This is the fallback for places no address search can find: a gate, a
/// market stall, a new estate.
class PinPickerScreen extends StatefulWidget {
  const PinPickerScreen({
    super.key,
    this.initialPoint,
    this.initialName = '',
    this.initialAddress = '',
  });

  final LatLng? initialPoint;
  final String initialName;
  final String initialAddress;

  @override
  State<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<PinPickerScreen> {
  static const double _pinSize = 38;

  final MapController _map = MapController();
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _address = TextEditingController(text: widget.initialAddress);
  late final ValueNotifier<LatLng> _center = ValueNotifier<LatLng>(
    widget.initialPoint ?? LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
  );
  bool _ready = false;
  bool _locating = false;

  @override
  void dispose() {
    _map.dispose();
    _name.dispose();
    _address.dispose();
    _center.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final point = await LocationService.current();
      if (!mounted) return;
      if (_ready) _map.move(point, 17);
    } on LocationException catch (e) {
      if (mounted) showInfo(context, e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final point = _ready ? _map.camera.center : _center.value;
    final lat = double.parse(point.latitude.toStringAsFixed(6));
    final lng = double.parse(point.longitude.toStringAsFixed(6));
    final name = _name.text.trim();
    final address = _address.text.trim();
    Navigator.of(context).pop(
      GeocodeResult(
        name: name.isEmpty ? 'Pinned location' : name,
        address: address.isEmpty ? 'Pin at ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : address,
        lat: lat,
        lng: lng,
        source: 'manual_pin',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final start = widget.initialPoint ?? LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
    return Scaffold(
      backgroundColor: c.canvas,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: start,
                      initialZoom: widget.initialPoint != null ? 17 : 13,
                      minZoom: 3,
                      maxZoom: 19,
                      backgroundColor: AppColors.mapBg,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () => _ready = true,
                      onPositionChanged: (camera, hasGesture) {
                        // Update after the frame: this can fire while the map is laying out.
                        final center = camera.center;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _center.value = center;
                        });
                      },
                    ),
                    children: [buildBaseTileLayer()],
                  ),
                ),
                // The pin stays fixed at the middle of the map; its tip marks the spot.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -_pinSize * 0.7),
                      child: const MapPin(label: '', icon: Icons.place_rounded, color: Color(0xFFF36F4B), size: _pinSize),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Back',
                          elevated: true,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: c.shadowSm,
                            ),
                            child: Text(
                              'Move the map so the pin is on the exact spot',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(13, c.ink, weight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: AppIconButton(
                    icon: _locating ? Icons.hourglass_top_rounded : Icons.my_location_rounded,
                    label: 'Go to my location',
                    elevated: true,
                    onPressed: _locating ? null : _useMyLocation,
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        baseTileAttribution(),
                        style: AppText.body(9.5, const Color(0xFF333333)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _center,
                      builder: (context, point, _) => Text(
                        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                        style: AppText.body(12, c.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      icon: Icons.storefront_outlined,
                      placeholder: 'Name this stop (e.g. Mama Tunde shop)',
                      controller: _name,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      icon: Icons.notes_rounded,
                      placeholder: 'Address or landmark (optional)',
                      controller: _address,
                      dense: true,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Use this location',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: _confirm,
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
}
