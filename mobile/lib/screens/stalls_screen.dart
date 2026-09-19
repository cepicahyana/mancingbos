import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'stall_form_screen.dart';

/// Daftar lapak milik pelapak (tab utama mode Pelapak).
class StallsScreen extends StatefulWidget {
  const StallsScreen({super.key});

  @override
  State<StallsScreen> createState() => _StallsScreenState();
}

class _StallsScreenState extends State<StallsScreen> {
  List<Stall> _stalls = [];
  bool _loading = true;
  String? _error;

  ApiClient get _api => context.read<AuthState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/stalls', query: {'mine': '1'});
      if (!mounted) return;
      setState(() => _stalls = asObjectList(res['data']).map(Stall.fromJson).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const StallFormScreen()));
    if (ok == true) _load();
  }

  Future<void> _edit(Stall st) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => StallFormScreen(stall: st)));
    if (ok == true) _load();
  }

  Future<void> _delete(Stall st) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah lapak'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Lapak Saya', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Kelola spot mancing milikmu — foto & video di tab Galeri',
                style: TextStyle(color: AppTheme.secondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _load,
                          child: _stalls.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 100),
                                    EmptyView(
                                      icon: Icons.storefront_outlined,
                                      title: 'Belum ada lapak',
                                      subtitle: 'Tambah lapak pancing untuk mulai buat event',
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
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
                                          '${st.location}\n'
                                          '${st.dailyRentPrice > 0 ? '${formatRp(st.dailyRentPrice)}/hari' : 'Tanpa harga sewa harian'}'
                                          ' · ${st.capacity} peserta/hari'
                                          '${st.active ? '' : ' · Nonaktif'}',
                                        ),
                                        isThreeLine: true,
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'edit') _edit(st);
                                            if (v == 'delete') _delete(st);
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
            ),
          ],
        ),
      ),
    );
  }
}
