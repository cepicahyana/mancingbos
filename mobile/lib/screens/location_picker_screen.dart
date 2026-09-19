import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';

class PickedLocation {
  const PickedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final PickedLocation? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> with SingleTickerProviderStateMixin {
  static const _default = LatLng(-6.2, 106.816666);

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _mapCtrl = Completer<GoogleMapController>();
  late final AnimationController _pinPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  Timer? _debounce;
  Timer? _reverseDebounce;
  LatLng _target = _default;
  String _label = '';
  bool _busy = false;
  bool _locating = true;
  bool _moving = false;
  bool _lockLabel = false; // keep searched place name until user pans
  List<Map<String, dynamic>> _suggestions = [];

  ApiClient get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _target = LatLng(init.latitude, init.longitude);
      _label = init.name;
      _locating = false;
    } else {
      _gotoCurrent();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reverseDebounce?.cancel();
    _pinPulse.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _gotoCurrent() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _target = here;
        _locating = false;
      });
      final map = await _mapCtrl.future;
      await map.animateCamera(CameraUpdate.newLatLngZoom(here, 15.5));
      await _reverse(here);
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String q) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _searchPlaces(q));
  }

  Future<void> _searchPlaces(String q) async {
    if (q.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final res = await _api.get('/api/places/autocomplete', query: {'q': q.trim()});
      if (!mounted) return;
      setState(() => _suggestions = asObjectList(res['data']));
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> item) async {
    final placeId = '${item['place_id'] ?? ''}';
    final fallbackName = '${item['description'] ?? ''}'.trim();
    if (placeId.isEmpty) return;
    _searchFocus.unfocus();
    setState(() {
      _busy = true;
      _suggestions = [];
      _search.text = fallbackName;
      _label = fallbackName;
      _lockLabel = true;
    });
    try {
      final res = await _api.get('/api/places/details', query: {'place_id': placeId});
      final data = res['data'] as Map<String, dynamic>;
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final detailName = '${data['name'] ?? ''}'.trim();
      final name = (detailName.isNotEmpty ? detailName : fallbackName);
      final short = name.length > 120 ? '${name.substring(0, 117)}...' : name;
      final target = LatLng(lat, lng);
      if (!mounted) return;
      setState(() {
        _target = target;
        _label = short;
        _lockLabel = true;
        _busy = false;
      });
      // Apply immediately so nama lokasi ikut ke form postingan
      Navigator.pop(
        context,
        PickedLocation(name: short, latitude: lat, longitude: lng),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (fallbackName.isNotEmpty) {
        // Still return search label if details fail but we have coords from... we don't.
        // Keep UI with fallback name so user can confirm manually after map settle.
        showAppError(context, e.firstError);
      } else {
        showAppError(context, e.firstError);
      }
    }
  }

  Future<void> _reverse(LatLng pos) async {
    if (_lockLabel) return;
    setState(() => _busy = true);
    try {
      final res = await _api.get('/api/places/reverse', query: {
        'lat': '${pos.latitude}',
        'lng': '${pos.longitude}',
      });
      final data = res['data'] as Map<String, dynamic>;
      if (!mounted) return;
      final name = '${data['name'] ?? ''}'.trim();
      if (name.isNotEmpty) setState(() => _label = name);
    } on ApiException catch (e) {
      if (mounted) {
        if (_label.isEmpty) {
          setState(() => _label = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
        }
        showAppError(context, e.firstError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirm() {
    final name = _label.trim().isEmpty
        ? '${_target.latitude.toStringAsFixed(5)}, ${_target.longitude.toStringAsFixed(5)}'
        : _label.trim();
    // Prefer a readable short name for the chip on posts
    final short = name.length > 120 ? '${name.substring(0, 117)}...' : name;
    Navigator.pop(
      context,
      PickedLocation(name: short, latitude: _target.latitude, longitude: _target.longitude),
    );
  }

  String get _title {
    if (_label.isEmpty) return 'Pilih titik di peta';
    final parts = _label.split(',');
    return parts.first.trim();
  }

  String get _subtitle {
    if (_label.isEmpty) return 'Geser peta atau cari nama tempat';
    final parts = _label.split(',');
    if (parts.length < 2) return _label;
    return parts.skip(1).join(',').trim();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.header,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _target, zoom: 14.5),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) {
              if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
            },
            onCameraMove: (pos) {
              _target = pos.target;
              if (_lockLabel) _lockLabel = false; // user moved map → allow reverse again
              if (!_moving) setState(() => _moving = true);
            },
            onCameraIdle: () {
              setState(() => _moving = false);
              _reverseDebounce?.cancel();
              _reverseDebounce = Timer(const Duration(milliseconds: 420), () => _reverse(_target));
            },
          ),

          // Center pin with pulse
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pinPulse,
                    builder: (_, _) {
                      final t = _moving ? 1.0 : _pinPulse.value;
                      return Transform.translate(
                        offset: Offset(0, _moving ? -10 : -4 - (t * 4)),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.header,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: AppTheme.header.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: const Icon(Icons.water_rounded, color: AppTheme.accent, size: 22),
                            ),
                            CustomPaint(
                              size: const Size(14, 10),
                              painter: _PinTailPainter(color: AppTheme.header),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  AnimatedOpacity(
                    opacity: _moving ? 0.9 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Lepas untuk set lokasi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top search chrome
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(14, top + 10, 14, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tag lokasi mancing',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                        ),
                      ),
                      _RoundBtn(icon: Icons.my_location_rounded, onTap: _gotoCurrent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(18),
                    child: TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cari danau, waduk, spot mancing...',
                        hintStyle: TextStyle(color: AppTheme.secondary.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                        suffixIcon: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                              )
                            : (_search.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _suggestions = []);
                                    },
                                    icon: const Icon(Icons.cancel_rounded, color: AppTheme.secondary),
                                  )),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      ),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: AppTheme.line),
                          itemBuilder: (_, i) {
                            final item = _suggestions[i];
                            final desc = '${item['description'] ?? ''}';
                            final parts = desc.split(',');
                            final title = parts.isEmpty ? desc : parts.first.trim();
                            final rest = parts.length > 1 ? parts.skip(1).join(',').trim() : '';
                            return InkWell(
                              onTap: () => _selectPlace(item),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.place_rounded, color: AppTheme.primaryDark, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                          if (rest.isNotEmpty)
                                            Text(rest, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.secondary, fontSize: 11.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom confirm card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottom + 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, -6))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD8DEDA), borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1FA86A), AppTheme.header]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.map_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _locating ? 'Mendeteksi lokasi...' : _title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _locating ? 'Tunggu sebentar' : _subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.secondary, fontSize: 12.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (_busy || _locating) ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.header,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.header.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text(_busy ? 'Memuat...' : 'Pakai lokasi ini', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  _PinTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) => oldDelegate.color != color;
}
