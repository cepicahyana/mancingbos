import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/geo.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import '../widgets/banner_slider.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.mine = false});

  final bool mine;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _search = TextEditingController();
  List<FishingEvent> _items = [];
  bool _loading = true;
  bool _locLoading = false;
  String? _error;
  double? _myLat;
  double? _myLng;
  String _myLabel = 'Mendeteksi lokasi…';

  _EventSort _sort = _EventSort.nearest;
  String _category = 'Semua';
  String _province = 'Semua';
  String _city = 'Semua';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _gridView = false;

  static const _competitionCats = [
    'galatama',
    'galapung',
    'kilogebrus',
    'casting',
    'feeder',
    'beregu',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    if (!widget.mine) _locateMe();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    setState(() => _locLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _myLabel = 'Lokasi tidak diizinkan';
            _locLoading = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      var label = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      try {
        final api = context.read<AuthState>().api;
        final rev = await api.get('/api/places/reverse', query: {
          'lat': '${pos.latitude}',
          'lng': '${pos.longitude}',
        });
        if (!mounted) return;
        final data = rev['data'];
        if (data is Map && '${data['name'] ?? ''}'.isNotEmpty) {
          label = '${data['name']}';
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
        _myLabel = label;
        _locLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _myLabel = 'Gagal membaca GPS';
          _locLoading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthState>().api;
      final query = <String, String>{
        'search': _search.text.trim(),
        'sort': 'date',
        'order': 'asc',
        'per_page': '100',
        if (widget.mine) 'mine': '1',
      };
      final res = await api.get('/api/events', query: query);
      _items = asObjectList(res['data']).map(FishingEvent.fromJson).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([_load(), if (!widget.mine) _locateMe()]);
  }

  double? _kmFor(FishingEvent e) {
    if (_myLat == null || _myLng == null) return null;
    if (e.latitude == null || e.longitude == null) return null;
    return distanceKm(_myLat!, _myLng!, e.latitude!, e.longitude!);
  }

  Map<String, int> get _provinceEventCounts {
    final m = <String, int>{};
    for (final e in _items) {
      final raw = eventProvince(e.location);
      if (raw.isEmpty) continue;
      final key = _canonicalProvince(raw);
      m[key] = (m[key] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> _cityEventCounts(String province) {
    final m = <String, int>{};
    for (final e in _items) {
      if (province != 'Semua' && _canonicalProvince(eventProvince(e.location)) != province) continue;
      final raw = eventCity(e.location);
      if (raw.isEmpty) continue;
      final key = _canonicalCity(raw, province);
      m[key] = (m[key] ?? 0) + 1;
    }
    return m;
  }

  String _canonicalProvince(String raw) {
    final t = raw.trim();
    for (final p in indonesianProvinces) {
      if (p.toLowerCase() == t.toLowerCase()) return p;
    }
    return t;
  }

  String _canonicalCity(String raw, String province) {
    final t = raw.trim();
    final known = citiesForProvince(province);
    for (final c in known) {
      if (regionNameMatch(c, t)) return c;
    }
    final stripped = t.replaceFirst(RegExp(r'^(kabupaten|kab\.?|kota)\s+', caseSensitive: false), '').trim();
    return stripped.isEmpty ? t : stripped;
  }

  List<FishingEvent> get _filtered {
    var list = _items.where((e) {
      if (_category != 'Semua' && e.category != _category) return false;
      if (_province != 'Semua' && _canonicalProvince(eventProvince(e.location)) != _province) return false;
      if (_city != 'Semua' && !regionNameMatch(eventCity(e.location), _city)) return false;
      final eventDay = DateTime.tryParse(e.date);
      if (eventDay != null) {
        final day = DateTime(eventDay.year, eventDay.month, eventDay.day);
        if (_dateFrom != null && day.isBefore(_dateFrom!)) return false;
        if (_dateTo != null && day.isAfter(_dateTo!)) return false;
      } else if (_dateFrom != null || _dateTo != null) {
        return false;
      }
      final q = _search.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final dateLabel = eventDay == null ? '' : DateFormat('d MMM yyyy', 'id').format(eventDay).toLowerCase();
        final dateIso = eventDay == null ? e.date.toLowerCase() : DateFormat('yyyy-MM-dd').format(eventDay);
        final hay = '${e.title} ${e.location} ${categoryLabel(e.category)} $dateLabel $dateIso'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case _EventSort.nearest:
        case _EventSort.farthest:
          final da = _kmFor(a);
          final db = _kmFor(b);
          if (da == null && db == null) return a.date.compareTo(b.date);
          if (da == null) return 1;
          if (db == null) return -1;
          return _sort == _EventSort.nearest ? da.compareTo(db) : db.compareTo(da);
        case _EventSort.priceLow:
          return a.registrationFee.compareTo(b.registrationFee);
        case _EventSort.priceHigh:
          return b.registrationFee.compareTo(a.registrationFee);
      }
    });
    return list;
  }

  String get _sortTitle => switch (_sort) {
        _EventSort.nearest => 'Event terdekat',
        _EventSort.farthest => 'Event terjauh',
        _EventSort.priceLow => 'Tiket termurah',
        _EventSort.priceHigh => 'Tiket termahal',
      };

  int get _activeFilterCount {
    var n = 0;
    if (_category != 'Semua') n++;
    if (_province != 'Semua') n++;
    if (_city != 'Semua') n++;
    if (_dateFrom != null || _dateTo != null) n++;
    return n;
  }

  bool get _hasFilters => _activeFilterCount > 0;

  String get _filterSummary {
    final parts = <String>[];
    if (_category != 'Semua') parts.add(categoryLabel(_category));
    if (_city != 'Semua') {
      parts.add(_city);
    } else if (_province != 'Semua') {
      parts.add(_province);
    }
    final dateLabel = _dateRangeLabel(_dateFrom, _dateTo);
    if (dateLabel != null) parts.add(dateLabel);
    return parts.join(' · ');
  }

  String? _dateRangeLabel(DateTime? from, DateTime? to) {
    if (from == null && to == null) return null;
    final fmt = DateFormat('d MMM', 'id');
    if (from != null && to != null) {
      if (from.year == to.year && from.month == to.month && from.day == to.day) {
        return DateFormat('d MMM yyyy', 'id').format(from);
      }
      return '${fmt.format(from)} – ${fmt.format(to)}';
    }
    if (from != null) return 'Dari ${fmt.format(from)}';
    return 'Sampai ${fmt.format(to!)}';
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _resetFilters() {
    setState(() {
      _category = 'Semua';
      _province = 'Semua';
      _city = 'Semua';
      _dateFrom = null;
      _dateTo = null;
    });
  }

  String _date(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('d MMM yyyy', 'id').format(parsed);
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<_EventSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text('Urutkan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                for (final s in _EventSort.values)
                  ListTile(
                    leading: Icon(s.icon, color: s == _sort ? AppTheme.primaryDark : AppTheme.secondary),
                    title: Text(s.label, style: TextStyle(fontWeight: s == _sort ? FontWeight.w800 : FontWeight.w500)),
                    trailing: s == _sort ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null,
                    onTap: () => Navigator.pop(ctx, s),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Future<void> _openFilterSheet() async {
    var cat = _category;
    var prov = _province;
    var city = _city;
    var from = _dateFrom;
    var to = _dateTo;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            List<MapEntry<String, int>> provinceOptions() {
              final counts = _provinceEventCounts;
              final total = counts.values.fold<int>(0, (a, b) => a + b);
              final entries = counts.entries.toList()
                ..sort((a, b) {
                  final byCount = b.value.compareTo(a.value);
                  if (byCount != 0) return byCount;
                  return a.key.compareTo(b.key);
                });
              return [MapEntry('Semua', total), ...entries];
            }

            List<MapEntry<String, int>> cityOptions(String p) {
              if (p == 'Semua') return const [MapEntry('Semua', 0)];
              final counts = _cityEventCounts(p);
              final total = counts.values.fold<int>(0, (a, b) => a + b);
              final entries = counts.entries.toList()
                ..sort((a, b) {
                  final byCount = b.value.compareTo(a.value);
                  if (byCount != 0) return byCount;
                  return a.key.compareTo(b.key);
                });
              return [MapEntry('Semua', total), ...entries];
            }

            Future<void> pickDate({required bool isFrom}) async {
              final now = DateTime.now();
              final initial = isFrom ? (from ?? to ?? now) : (to ?? from ?? now);
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
                locale: const Locale('id'),
                helpText: isFrom ? 'Tanggal mulai' : 'Tanggal akhir',
                cancelText: 'Batal',
                confirmText: 'Pilih',
              );
              if (picked == null) return;
              setLocal(() {
                final day = _dayOnly(picked);
                if (isFrom) {
                  from = day;
                  if (to != null && to!.isBefore(from!)) to = from;
                } else {
                  to = day;
                  if (from != null && from!.isAfter(to!)) from = to;
                }
              });
            }

            Widget countedSection(
              String title,
              List<MapEntry<String, int>> items,
              String selected,
              void Function(String) onPick, {
              String Function(String)? labelOf,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.secondary)),
                    const SizedBox(height: 6),
                    if (items.where((e) => e.key != 'Semua').isEmpty && title.startsWith('Provinsi'))
                      Text(
                        'Belum ada event dengan data wilayah',
                        style: TextStyle(fontSize: 12, color: AppTheme.secondary.withValues(alpha: 0.9)),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final entry in items)
                            ChoiceChip(
                              label: Text(
                                () {
                                  final base = labelOf?.call(entry.key) ?? entry.key;
                                  if (entry.value < 0) return base;
                                  return '$base (${entry.value})';
                                }(),
                              ),
                              selected: entry.key == selected,
                              onSelected: (_) => setLocal(() => onPick(entry.key)),
                              selectedColor: AppTheme.primarySoft,
                              backgroundColor: const Color(0xFFF4F7F5),
                              labelStyle: TextStyle(
                                color: entry.key == selected ? AppTheme.primaryDark : AppTheme.ink,
                                fontWeight: entry.key == selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: entry.key == selected ? AppTheme.primary : AppTheme.line,
                                width: entry.key == selected ? 1.3 : 1,
                              ),
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            }

            Widget section(
              String title,
              List<String> items,
              String selected,
              void Function(String) onPick, {
              String Function(String)? labelOf,
            }) {
              return countedSection(
                title,
                [for (final v in items) MapEntry(v, -1)],
                selected,
                onPick,
                labelOf: labelOf,
              );
            }

            Widget dateBtn(String label, DateTime? value, VoidCallback onTap) {
              return Expanded(
                child: Material(
                  color: const Color(0xFFF4F7F5),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: value != null ? AppTheme.primary : AppTheme.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: value != null ? AppTheme.primaryDark : AppTheme.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              value == null ? label : DateFormat('d MMM yyyy', 'id').format(value),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: value != null ? AppTheme.ink : AppTheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            Widget datePreset(String label, {required VoidCallback onTap, bool selected = false, bool danger = false}) {
              final bg = selected ? AppTheme.primarySoft : Colors.white;
              final border = danger
                  ? const Color(0xFFD64545)
                  : (selected ? AppTheme.primary : AppTheme.line);
              final fg = danger
                  ? const Color(0xFFD64545)
                  : (selected ? AppTheme.primaryDark : AppTheme.ink);
              return Material(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: border, width: selected || danger ? 1.3 : 1),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                ),
              );
            }

            ChipThemeData slimChipTheme(BuildContext c) => ChipTheme.of(c).copyWith(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                );

            final today = _dayOnly(DateTime.now());
            final weekEnd = today.add(const Duration(days: 6));
            final monthEnd = DateTime(today.year, today.month + 1, 0);
            final bottom = MediaQuery.paddingOf(ctx).bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(99)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 2),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Filter event', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => setLocal(() {
                              cat = 'Semua';
                              prov = 'Semua';
                              city = 'Semua';
                              from = null;
                              to = null;
                            }),
                            child: const Text('Reset', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                        child: ChipTheme(
                          data: slimChipTheme(ctx),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tanggal event', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.secondary)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        datePreset(
                                          'Hari ini',
                                          selected: from == today && to == today,
                                          onTap: () => setLocal(() {
                                            from = today;
                                            to = today;
                                          }),
                                        ),
                                        datePreset(
                                          '7 hari ke depan',
                                          selected: from == today && to == weekEnd,
                                          onTap: () => setLocal(() {
                                            from = today;
                                            to = weekEnd;
                                          }),
                                        ),
                                        datePreset(
                                          'Bulan ini',
                                          selected: from == DateTime(today.year, today.month, 1) && to == monthEnd,
                                          onTap: () => setLocal(() {
                                            from = DateTime(today.year, today.month, 1);
                                            to = monthEnd;
                                          }),
                                        ),
                                        if (from != null || to != null)
                                          datePreset(
                                            'Hapus tanggal',
                                            selected: false,
                                            danger: true,
                                            onTap: () => setLocal(() {
                                              from = null;
                                              to = null;
                                            }),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        dateBtn('Dari tanggal', from, () => pickDate(isFrom: true)),
                                        const SizedBox(width: 6),
                                        dateBtn('Sampai', to, () => pickDate(isFrom: false)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              section(
                                'Jenis kategori',
                                ['Semua', ..._competitionCats],
                                cat,
                                (v) => cat = v,
                                labelOf: (v) => v == 'Semua' ? 'Semua' : categoryLabel(v),
                              ),
                              countedSection(
                                'Provinsi',
                                provinceOptions(),
                                prov,
                                (v) {
                                  prov = v;
                                  city = 'Semua';
                                },
                              ),
                              if (prov != 'Semua')
                                countedSection(
                                  'Kabupaten / Kota',
                                  cityOptions(prov),
                                  city,
                                  (v) => city = v,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14, 4, 14, 8 + bottom),
                      child: SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _category = cat;
        _province = prov;
        _city = city;
        _dateFrom = from;
        _dateTo = to;
      });
    }
  }

  Widget _toolPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    int? badge,
  }) {
    return Material(
      color: active ? AppTheme.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppTheme.primary : AppTheme.line, width: active ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: active ? AppTheme.primaryDark : AppTheme.secondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: active ? AppTheme.primaryDark : AppTheme.ink,
                  ),
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(99)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ] else
                Icon(Icons.expand_more_rounded, size: 18, color: active ? AppTheme.primaryDark : AppTheme.secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onClear) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onDeleted: onClear,
      deleteIconColor: AppTheme.primaryDark,
      backgroundColor: AppTheme.primarySoft,
      side: const BorderSide(color: AppTheme.primary),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(left: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mine) return _mineBody(context);
    return _homeBody(context);
  }

  Widget _mineBody(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EventFormScreen()));
          if (ok == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat event'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Event Saya', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(child: _listArea()),
          ],
        ),
      ),
    );
  }

  Widget _homeBody(BuildContext context) {
    final user = context.watch<AuthState>().user!;
    final openRentals = _items.where((e) => e.rentalEnabled).length;
    final top = MediaQuery.paddingOf(context).top;
    final sorted = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _refreshHome,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                topInset: top,
                name: user.name.split(' ').first,
                eventCount: _items.length,
                rentalCount: openRentals,
                onRefresh: _refreshHome,
              ),
            ),
            const SpiverGap(12),
            const SliverToBoxAdapter(child: PromoBannerCarousel()),
            const SpiverGap(18),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_sortTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                    const SizedBox(height: 4),
                    Text(
                      _hasFilters
                          ? '${sorted.length} event · $_filterSummary'
                          : '${sorted.length} event tersedia',
                      style: const TextStyle(color: AppTheme.secondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _locateMe,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.line),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _myLat != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
                                  color: AppTheme.primaryDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Lokasi Anda', style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _locLoading ? 'Mendeteksi lokasi…' : _myLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (_locLoading)
                                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                              else
                                const Icon(Icons.refresh_rounded, color: AppTheme.secondary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Cari judul, lokasi, atau tanggal',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? IconButton(
                                tooltip: 'Pilih tanggal',
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dateFrom ?? now,
                                    firstDate: DateTime(now.year - 1),
                                    lastDate: DateTime(now.year + 2),
                                    locale: const Locale('id'),
                                    helpText: 'Cari tanggal event',
                                    cancelText: 'Batal',
                                    confirmText: 'Cari',
                                  );
                                  if (picked == null || !mounted) return;
                                  final day = _dayOnly(picked);
                                  setState(() {
                                    _dateFrom = day;
                                    _dateTo = day;
                                  });
                                },
                                icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
                              )
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _toolPill(
                            icon: Icons.swap_vert_rounded,
                            label: _sort.label,
                            onTap: _openSortSheet,
                            active: _sort != _EventSort.nearest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _toolPill(
                            icon: Icons.tune_rounded,
                            label: _hasFilters ? 'Filter aktif' : 'Filter',
                            onTap: _openFilterSheet,
                            active: _hasFilters,
                            badge: _activeFilterCount > 0 ? _activeFilterCount : null,
                          ),
                        ),
                      ],
                    ),
                    if (_hasFilters) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_category != 'Semua')
                            _activeChip(categoryLabel(_category), () => setState(() => _category = 'Semua')),
                          if (_province != 'Semua')
                            _activeChip(_province, () => setState(() {
                                  _province = 'Semua';
                                  _city = 'Semua';
                                })),
                          if (_city != 'Semua') _activeChip(_city, () => setState(() => _city = 'Semua')),
                          if (_dateFrom != null || _dateTo != null)
                            _activeChip(_dateRangeLabel(_dateFrom, _dateTo)!, () => setState(() {
                                  _dateFrom = null;
                                  _dateTo = null;
                                })),
                          GestureDetector(
                            onTap: _resetFilters,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text('Hapus semua', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SpiverGap(10),
            if (!_loading && _error == null && sorted.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        '${sorted.length} event',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.secondary),
                      ),
                      const Spacer(),
                      _ViewModeToggle(
                        grid: _gridView,
                        onChanged: (grid) => setState(() => _gridView = grid),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SpiverGap(4),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
            else if (_error != null)
              SliverFillRemaining(child: ErrorView(message: _error!, onRetry: _load))
            else if (sorted.isEmpty)
              SpiverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: Icons.water_rounded,
                  title: _hasFilters || _search.text.isNotEmpty ? 'Tidak ada hasil' : 'Belum ada event',
                  subtitle: _hasFilters || _search.text.isNotEmpty
                      ? 'Coba ubah filter, urutan, atau kata kunci.'
                      : 'Event mancing akan tampil di sini.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: _gridView
                    ? SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final ev = sorted[i];
                            return _EventGridCard(
                              event: ev,
                              dateLabel: _date(ev.date),
                              distanceLabel: formatDistanceKm(_kmFor(ev)),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(id: ev.id)));
                                _load();
                              },
                            );
                          },
                          childCount: sorted.length,
                        ),
                      )
                    : SliverList.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final ev = sorted[i];
                          return _EventListCard(
                            event: ev,
                            dateLabel: _date(ev.date),
                            distanceLabel: formatDistanceKm(_kmFor(ev)),
                            rank: i + 1,
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(id: ev.id)));
                              _load();
                            },
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _listArea() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return const EmptyView(icon: Icons.water_rounded, title: 'Belum ada event', subtitle: 'Event mancing akan tampil di sini.');
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final ev = _items[i];
          return _EventListCard(
            event: ev,
            dateLabel: _date(ev.date),
            distanceLabel: formatDistanceKm(_kmFor(ev)),
            rank: i + 1,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(id: ev.id)));
              _load();
            },
          );
        },
      ),
    );
  }
}

class SpiverGap extends StatelessWidget {
  const SpiverGap(this.height, {super.key});
  final double height;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: SizedBox(height: height));
}

class SpiverFillRemaining extends StatelessWidget {
  const SpiverFillRemaining({super.key, required this.child, this.hasScrollBody = true});
  final Widget child;
  final bool hasScrollBody;
  @override
  Widget build(BuildContext context) => SliverFillRemaining(hasScrollBody: hasScrollBody, child: child);
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.topInset,
    required this.name,
    required this.eventCount,
    required this.rentalCount,
    required this.onRefresh,
  });

  final double topInset;
  final String name;
  final int eventCount;
  final int rentalCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.header, Color(0xFF0E5A45)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hai, $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('Mau mancing di mana hari ini?', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  ],
                ),
              ),
              _roundIcon(Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C4A3C),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _stat(Icons.emoji_events_rounded, 'Event aktif', '$eventCount')),
                    Container(width: 1, height: 34, color: Colors.white24),
                    Expanded(child: _stat(Icons.confirmation_number_rounded, 'Sewa dibuka', '$rentalCount tersedia')),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickAction(icon: Icons.water_rounded, label: 'Event', color: Color(0xFF0B6B4F)),
                      _QuickAction(icon: Icons.storefront_rounded, label: 'Sewa', color: Color(0xFF1FA86A)),
                      _QuickAction(icon: Icons.monitor_weight_rounded, label: 'Berat', color: Color(0xFF7B61FF), badge: 'New'),
                      _QuickAction(icon: Icons.map_rounded, label: 'Lokasi', color: Color(0xFFE25563), badge: 'New'),
                      _QuickAction(icon: Icons.groups_rounded, label: 'Komunitas', color: Color(0xFF3B82F6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, this.badge});

  final IconData icon;
  final String label;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            if (badge != null)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFFF7A1A), borderRadius: BorderRadius.circular(8)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.ink)),
      ],
    );
  }
}

class _EventListCard extends StatelessWidget {
  const _EventListCard({
    required this.event,
    required this.dateLabel,
    required this.onTap,
    this.distanceLabel,
    this.rank = 0,
  });

  final FishingEvent event;
  final String dateLabel;
  final String? distanceLabel;
  final int rank;
  final VoidCallback onTap;

  Color get _catColor => switch (event.category) {
        'galatama' || 'lomba_jumlah' => const Color(0xFF0B6B4F),
        'galapung' || 'santuy' => const Color(0xFF0284C7),
        'kilogebrus' || 'lomba_berat' => const Color(0xFFB45309),
        'casting' => const Color(0xFF7C3AED),
        'feeder' => const Color(0xFF1D4ED8),
        'beregu' || 'team' => const Color(0xFFBE185D),
        _ => const Color(0xFF0F766E),
      };

  @override
  Widget build(BuildContext context) {
    final fee = formatRp(event.registrationFee);
    final quota = event.maxParticipants > 0
        ? '${event.participantsCount}/${event.maxParticipants}'
        : '${event.participantsCount}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.line),
            boxShadow: [
              BoxShadow(color: const Color(0xFF064536).withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero strip
              Container(
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_catColor, _catColor.withValues(alpha: 0.72), const Color(0xFF0A3D32)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -12,
                      bottom: -18,
                      child: Icon(Icons.set_meal_rounded, size: 110, color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    Positioned(
                      left: -20,
                      top: -20,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (rank > 0 && rank <= 3)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC6FF00),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '#$rank terdekat',
                                    style: const TextStyle(color: AppTheme.ink, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  categoryLabel(event.category),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const Spacer(),
                              if (distanceLabel != null && distanceLabel != '—')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.near_me_rounded, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        distanceLabel!,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.secondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(dateLabel, style: const TextStyle(color: AppTheme.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        const Icon(Icons.groups_outlined, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('$quota peserta', style: const TextStyle(color: AppTheme.secondary, fontSize: 12)),
                        if (event.rentalEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('Sewa', style: TextStyle(color: AppTheme.primaryDark, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3FAF6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD8EBE1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: const Icon(Icons.payments_rounded, color: AppTheme.primaryDark, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Harga pendaftaran', style: TextStyle(color: AppTheme.secondary, fontSize: 11)),
                                Text(
                                  fee,
                                  style: TextStyle(
                                    color: event.registrationFee > 0 ? AppTheme.ink : AppTheme.primaryDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Lihat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.view_agenda_rounded, !grid, () => onChanged(false)),
          _btn(Icons.grid_view_rounded, grid, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool active, VoidCallback onTap) {
    return Material(
      color: active ? AppTheme.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: active ? AppTheme.primaryDark : AppTheme.secondary),
        ),
      ),
    );
  }
}

class _EventGridCard extends StatelessWidget {
  const _EventGridCard({
    required this.event,
    required this.dateLabel,
    required this.onTap,
    this.distanceLabel,
  });

  final FishingEvent event;
  final String dateLabel;
  final String? distanceLabel;
  final VoidCallback onTap;

  Color get _catColor => switch (event.category) {
        'galatama' || 'lomba_jumlah' => const Color(0xFF0B6B4F),
        'galapung' || 'santuy' => const Color(0xFF0284C7),
        'kilogebrus' || 'lomba_berat' => const Color(0xFFB45309),
        'casting' => const Color(0xFF7C3AED),
        'feeder' => const Color(0xFF1D4ED8),
        'beregu' || 'team' => const Color(0xFFBE185D),
        _ => const Color(0xFF0F766E),
      };

  @override
  Widget build(BuildContext context) {
    final fee = formatRp(event.registrationFee);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
            boxShadow: [
              BoxShadow(color: const Color(0xFF064536).withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_catColor, _catColor.withValues(alpha: 0.75), const Color(0xFF0A3D32)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -8,
                        bottom: -10,
                        child: Icon(Icons.set_meal_rounded, size: 72, color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      categoryLabel(event.category),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                if (distanceLabel != null && distanceLabel != '—') ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      distanceLabel!,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(dateLabel, style: const TextStyle(color: AppTheme.ink, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        fee,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: event.registrationFee > 0 ? AppTheme.ink : AppTheme.primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _EventSort {
  nearest,
  farthest,
  priceLow,
  priceHigh;

  String get label => switch (this) {
        nearest => 'Terdekat',
        farthest => 'Terjauh',
        priceLow => 'Termurah',
        priceHigh => 'Termahal',
      };

  IconData get icon => switch (this) {
        nearest => Icons.near_me_rounded,
        farthest => Icons.explore_rounded,
        priceLow => Icons.arrow_downward_rounded,
        priceHigh => Icons.arrow_upward_rounded,
      };
}
