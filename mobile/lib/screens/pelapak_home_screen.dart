import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'event_form_screen.dart';
import 'stall_form_screen.dart';

class PelapakHomeScreen extends StatefulWidget {
  const PelapakHomeScreen({super.key});

  @override
  State<PelapakHomeScreen> createState() => _PelapakHomeScreenState();
}

class _PelapakHomeScreenState extends State<PelapakHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Stall> _stalls = [];
  List<FishingEvent> _events = [];
  bool _loading = true;
  String? _error;

  ApiClient get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stallsRes = await _api.get('/api/stalls', query: {'mine': '1'});
      final eventsRes = await _api.get('/api/events', query: {'mine': '1'});
      if (!mounted) return;
      setState(() {
        _stalls = asObjectList(stallsRes['data']).map(Stall.fromJson).toList();
        _events = asObjectList(eventsRes['data']).map(FishingEvent.fromJson).toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStall() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const StallFormScreen()));
    if (ok == true) _load();
  }

  Future<void> _editStall(Stall st) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => StallFormScreen(stall: st)));
    if (ok == true) _load();
  }

  Future<void> _deleteStall(Stall st) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus lapak'),
        content: Text('Hapus "${st.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.delete('/api/stalls/${st.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _addEvent() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EventFormScreen()));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Kelola Pelapak'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor: AppTheme.secondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Lapak saya'),
            Tab(text: 'Event saya'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabs.index == 0) {
            _addStall();
          } else {
            _addEvent();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabs.index == 0 ? 'Tambah lapak' : 'Buat event'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _load,
                      child: _stalls.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                EmptyView(icon: Icons.storefront_outlined, title: 'Belum ada lapak', subtitle: 'Tambah lapak pancing milikmu'),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                              itemCount: _stalls.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final st = _stalls[i];
                                return SoftPanel(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    leading: const IconBadge(icon: Icons.storefront_rounded, size: 42),
                                    title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                      '${st.location}\n${st.dailyRentPrice > 0 ? '${formatRp(st.dailyRentPrice)}/hari' : 'Tanpa harga sewa harian'}'
                                      '${st.active ? '' : ' · Nonaktif'}',
                                    ),
                                    isThreeLine: true,
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _editStall(st);
                                        if (v == 'delete') _deleteStall(st);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Ubah')),
                                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _load,
                      child: _events.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                EmptyView(icon: Icons.event_note_outlined, title: 'Belum ada event', subtitle: 'Buat event mancing di lapakmu'),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                              itemCount: _events.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final ev = _events[i];
                                return SoftPanel(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    leading: const IconBadge(icon: Icons.water_rounded, size: 42),
                                    title: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                      '${ev.date} · ${categoryLabel(ev.category)}\n'
                                      '${ev.participantsCount}${ev.maxParticipants > 0 ? '/${ev.maxParticipants}' : ''} peserta · ${formatRp(ev.registrationFee)}',
                                    ),
                                    isThreeLine: true,
                                    onTap: () async {
                                      final ok = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(builder: (_) => EventFormScreen(event: ev)),
                                      );
                                      if (ok == true) _load();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
