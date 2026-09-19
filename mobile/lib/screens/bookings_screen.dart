import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/geo.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  DateTime _date = DateTime.now();
  List<Stall> _stalls = [];
  List<Booking> _mine = [];
  bool _loadingStalls = true;
  bool _loadingMine = true;
  String? _stallError;
  String? _mineError;
  String _scheme = 'Semua';
  String _province = 'Semua';
  String _city = 'Semua';
  _HarianSort _sort = _HarianSort.slots;

  static const _schemes = [
    'kilogebrus',
    'borongan',
    'kilogebrus_borongan',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadStalls();
    _loadMine();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  String get _dateIso => DateFormat('yyyy-MM-dd').format(_date);
  String get _dateLabel => DateFormat('EEE, d MMM yyyy', 'id').format(_date);

  String _schemeLabel(String v) => switch (v) {
        'borongan' => 'Borongan',
        'kilogebrus_borongan' => 'Kilogebrus + Borongan',
        'kilogebrus' => 'Kilogebrus',
        _ => 'Semua',
      };

  int get _activeFilterCount {
    var n = 0;
    if (_scheme != 'Semua') n++;
    if (_province != 'Semua') n++;
    if (_city != 'Semua') n++;
    return n;
  }

  bool get _hasFilters => _activeFilterCount > 0;

  String get _filterSummary {
    final parts = <String>[];
    if (_scheme != 'Semua') parts.add(_schemeLabel(_scheme));
    if (_city != 'Semua') {
      parts.add(_city);
    } else if (_province != 'Semua') {
      parts.add(_province);
    }
    return parts.join(' · ');
  }

  List<Stall> get _filtered {
    var list = _stalls.where((s) {
      if (_scheme != 'Semua' && s.scheme != _scheme) return false;
      if (_province != 'Semua') {
        final p = eventProvince(s.location);
        if (p.toLowerCase() != _province.toLowerCase() && !s.location.toLowerCase().contains(_province.toLowerCase())) {
          return false;
        }
      }
      if (_city != 'Semua' && !regionNameMatch(eventCity(s.location), _city)) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case _HarianSort.priceLow:
          return a.dailyRentPrice.compareTo(b.dailyRentPrice);
        case _HarianSort.priceHigh:
          return b.dailyRentPrice.compareTo(a.dailyRentPrice);
        case _HarianSort.slots:
          return b.remainingSlots.compareTo(a.remainingSlots);
        case _HarianSort.name:
          return a.name.compareTo(b.name);
      }
    });
    return list;
  }

  void _resetFilters() {
    setState(() {
      _scheme = 'Semua';
      _province = 'Semua';
      _city = 'Semua';
    });
    _loadStalls();
  }

  Future<void> _loadStalls() async {
    setState(() {
      _loadingStalls = true;
      _stallError = null;
    });
    try {
      final res = await context.read<AuthState>().api.get('/api/stalls', query: {
        'date': _dateIso,
        'search': _search.text.trim(),
        'available_only': '1',
        'harian': '1',
      });
      _stalls = asObjectList(res['data']).map(Stall.fromJson).toList();
    } on ApiException catch (e) {
      _stallError = e.message;
    } finally {
      if (mounted) setState(() => _loadingStalls = false);
    }
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingMine = true;
      _mineError = null;
    });
    try {
      final res = await context.read<AuthState>().api.get('/api/bookings');
      _mine = asObjectList(res['data']).map(Booking.fromJson).toList();
    } on ApiException catch (e) {
      _mineError = e.message;
    } finally {
      if (mounted) setState(() => _loadingMine = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('id'),
      helpText: 'Pilih tanggal mancing',
      cancelText: 'Batal',
      confirmText: 'Cek ketersediaan',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _loadStalls();
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<_HarianSort>(
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
                for (final s in _HarianSort.values)
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
    var scheme = _scheme;
    var prov = _province;
    var city = _city;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget countedSection(String title, List<MapEntry<String, int>> items, String selected, void Function(String) onPick, {String Function(String)? labelOf}) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.secondary)),
                    const SizedBox(height: 6),
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
                            side: BorderSide(color: entry.key == selected ? AppTheme.primary : AppTheme.line, width: entry.key == selected ? 1.3 : 1),
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

            Map<String, int> schemeCounts() {
              final m = <String, int>{};
              for (final s in _stalls) {
                m[s.scheme] = (m[s.scheme] ?? 0) + 1;
              }
              return m;
            }

            Map<String, int> provinceCounts() {
              final m = <String, int>{};
              for (final s in _stalls) {
                final p = eventProvince(s.location);
                if (p.isEmpty) continue;
                m[p] = (m[p] ?? 0) + 1;
              }
              return m;
            }

            Map<String, int> cityCounts(String p) {
              final m = <String, int>{};
              for (final s in _stalls) {
                if (p != 'Semua' && eventProvince(s.location) != p) continue;
                final c = eventCity(s.location);
                if (c.isEmpty) continue;
                m[c] = (m[c] ?? 0) + 1;
              }
              return m;
            }

            List<MapEntry<String, int>> withSemua(Map<String, int> counts) {
              final total = counts.values.fold<int>(0, (a, b) => a + b);
              final entries = counts.entries.toList()
                ..sort((a, b) {
                  final byCount = b.value.compareTo(a.value);
                  if (byCount != 0) return byCount;
                  return a.key.compareTo(b.key);
                });
              return [MapEntry('Semua', total), ...entries];
            }

            final bottom = MediaQuery.paddingOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    Container(width: 32, height: 3, decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(99))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 2),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Filter harian', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () => setLocal(() {
                              scheme = 'Semua';
                              prov = 'Semua';
                              city = 'Semua';
                            }),
                            child: const Text('Reset', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            countedSection(
                              'Kategori mancing',
                              [
                                MapEntry('Semua', _stalls.length),
                                ..._schemes.map((s) => MapEntry(s, schemeCounts()[s] ?? 0)),
                              ],
                              scheme,
                              (v) => scheme = v,
                              labelOf: _schemeLabel,
                            ),
                            countedSection(
                              'Provinsi',
                              withSemua(provinceCounts()),
                              prov,
                              (v) {
                                prov = v;
                                city = 'Semua';
                              },
                            ),
                            if (prov != 'Semua')
                              countedSection(
                                'Kabupaten / Kota',
                                withSemua(cityCounts(prov)),
                                city,
                                (v) => city = v,
                              ),
                          ],
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
        _scheme = scheme;
        _province = prov;
        _city = city;
      });
      await _loadStalls();
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active ? AppTheme.primaryDark : AppTheme.ink),
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

  Future<void> _book(Stall st) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pesan harian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(st.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(st.location, style: const TextStyle(color: AppTheme.secondary, fontSize: 13)),
            const SizedBox(height: 12),
            Text('Tanggal: $_dateLabel'),
            Text('Sisa slot: ${st.remainingSlots}/${st.capacity} peserta'),
            Text('Skema: ${st.schemeLabel}'),
            Text('Harga: ${st.dailyRentPrice > 0 ? formatRp(st.dailyRentPrice) : 'Bayar di lokasi (kilogebrus)'}/hari'),
            const SizedBox(height: 8),
            const Text(
              'Mancing harian: kilogebrus (bayar berat) atau borongan (paket spot). Satu pesan = 1 slot.',
              style: TextStyle(fontSize: 12, color: AppTheme.secondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pesan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthState>().api.post('/api/bookings', {
        'stall_id': st.id,
        'rental_date': _dateIso,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan sewa terkirim')));
      _tabs.animateTo(1);
      await Future.wait([_loadStalls(), _loadMine()]);
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _openCalendar(Stall st) async {
    try {
      final res = await context.read<AuthState>().api.get('/api/stalls/${st.id}/availability', query: {'days': '45'});
      if (!mounted) return;
      final days = asObjectList(res['data']).map(StallDayAvailability.fromJson).toList();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.62,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, scroll) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(99))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('${st.schemeLabel} · kapasitas ${st.capacity}/hari', style: const TextStyle(color: AppTheme.secondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: days.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final d = days[i];
                        final label = DateFormat('EEE, d MMM yyyy', 'id').format(DateTime.parse(d.date));
                        final status = d.blockedByEvent
                            ? 'Ada event'
                            : (d.notOpenOnDate
                                ? 'Belum dibuka pelapak'
                                : (d.available ? 'Tersedia · sisa ${d.remainingSlots}' : 'Penuh'));
                        return Material(
                          color: d.available ? AppTheme.primarySoft : const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: !d.available
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    setState(() => _date = DateTime.parse(d.date));
                                    _loadStalls();
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    d.available ? Icons.event_available_rounded : Icons.event_busy_rounded,
                                    color: d.available ? AppTheme.primaryDark : AppTheme.secondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        Text(status, style: TextStyle(fontSize: 12, color: d.available ? AppTheme.primaryDark : AppTheme.secondary)),
                                      ],
                                    ),
                                  ),
                                  if (d.available) const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _cancel(Booking b) async {
    try {
      await context.read<AuthState>().api.delete('/api/bookings/${b.id}');
      _loadMine();
      _loadStalls();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().user!;
    final shown = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Harian', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  Text('Kolam buka tiap hari · kilogebrus & borongan', style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.primaryDark,
              unselectedLabelColor: AppTheme.secondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Cari lapak'),
                Tab(text: 'Pesanan saya'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _browseTab(shown),
                  _mineTab(me),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _browseTab(List<Stall> shown) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau lokasi lapak',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: _loadStalls,
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primary),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _loadStalls(),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryDark, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal mancing', style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w600)),
                              Text(_dateLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            ],
                          ),
                        ),
                        const Text('Ubah', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _toolPill(
                      icon: Icons.swap_vert_rounded,
                      label: _sort.label,
                      onTap: _openSortSheet,
                      active: _sort != _HarianSort.slots,
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
                    if (_scheme != 'Semua')
                      _activeChip(_schemeLabel(_scheme), () {
                        setState(() => _scheme = 'Semua');
                        _loadStalls();
                      }),
                    if (_province != 'Semua')
                      _activeChip(_province, () {
                        setState(() {
                          _province = 'Semua';
                          _city = 'Semua';
                        });
                        _loadStalls();
                      }),
                    if (_city != 'Semua')
                      _activeChip(_city, () {
                        setState(() => _city = 'Semua');
                        _loadStalls();
                      }),
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
              const SizedBox(height: 6),
              Text(
                _hasFilters ? '${shown.length} lapak · $_filterSummary' : '${shown.length} lapak tersedia',
                style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingStalls
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _stallError != null
                  ? ErrorView(message: _stallError!, onRetry: _loadStalls)
                  : shown.isEmpty
                      ? const EmptyView(
                          icon: Icons.storefront_outlined,
                          title: 'Tidak ada lapak tersedia',
                          subtitle: 'Coba ubah tanggal, wilayah, atau kategori mancing.',
                        )
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _loadStalls,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final st = shown[i];
                              return SoftCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const IconBadge(icon: Icons.storefront_rounded),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(st.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              Text(st.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.secondary, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (st.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(st.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppTheme.ink)),
                                    ],
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _metaChip(Icons.set_meal_rounded, st.schemeLabel),
                                        _metaChip(Icons.groups_rounded, 'Sisa ${st.remainingSlots}/${st.capacity}'),
                                        _metaChip(
                                          Icons.payments_outlined,
                                          st.dailyRentPrice > 0 ? '${formatRp(st.dailyRentPrice)}/hari' : 'Kilogebrus',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        TextButton(onPressed: () => _openCalendar(st), child: const Text('Lihat tanggal')),
                                        const Spacer(),
                                        FilledButton(
                                          onPressed: () => _book(st),
                                          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                                          child: const Text('Pesan'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8EBE1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryDark),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
        ],
      ),
    );
  }

  Widget _mineTab(User me) {
    if (_loadingMine) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_mineError != null) return ErrorView(message: _mineError!, onRetry: _loadMine);
    if (_mine.isEmpty) {
      return const EmptyView(
        icon: Icons.receipt_long_rounded,
        title: 'Belum ada pesanan',
        subtitle: 'Pesan lapak dari tab Cari lapak dengan tanggal yang tersedia.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadMine,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _mine.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final b = _mine[i];
          final dateLabel = b.rentalDate.isEmpty
              ? ''
              : DateFormat('d MMM yyyy', 'id').format(DateTime.tryParse(b.rentalDate) ?? DateTime.now());
          return SoftCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconBadge(icon: Icons.storefront_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.stallName.isNotEmpty ? b.stallName : b.eventTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (dateLabel.isNotEmpty) dateLabel,
                          if (b.stallLocation.isNotEmpty) b.stallLocation,
                          if (b.eventId != null) b.eventTitle,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: const TextStyle(color: AppTheme.secondary, fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      StatusPill(
                        label: bookingStatusLabel(b.status),
                        positive: b.status == 'approved' || b.status == 'pending',
                      ),
                    ],
                  ),
                ),
                if (b.userId == me.id && b.status == 'pending')
                  TextButton(onPressed: () => _cancel(b), child: const Text('Batal')),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _HarianSort {
  slots,
  priceLow,
  priceHigh,
  name;

  String get label => switch (this) {
        slots => 'Slot terbanyak',
        priceLow => 'Termurah',
        priceHigh => 'Termahal',
        name => 'Nama A-Z',
      };

  IconData get icon => switch (this) {
        slots => Icons.groups_rounded,
        priceLow => Icons.arrow_downward_rounded,
        priceHigh => Icons.arrow_upward_rounded,
        name => Icons.sort_by_alpha_rounded,
      };
}
