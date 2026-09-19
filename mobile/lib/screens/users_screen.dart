import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  List<User> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<AuthState>().api.get('/api/users', query: {'search': _search.text.trim()});
      _items = asObjectList(res['data']).map(User.fromJson).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(User u) async {
    final name = TextEditingController(text: u.name);
    var role = u.role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ubah pengguna'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: fieldDeco('Nama')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: fieldDeco('Peran'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Pencinta Mancing')),
                  DropdownMenuItem(value: 'owner', child: Text('Pemilik Lapak')),
                  DropdownMenuItem(value: 'operator', child: Text('Operator')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'superadmin', child: Text('Superadmin')),
                ],
                onChanged: (v) => setLocal(() => role = v ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthState>().api.patch('/api/users/${u.id}', {'name': name.text.trim(), 'role': role});
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _delete(User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pengguna'),
        content: Text('Hapus ${u.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthState>().api.delete('/api/users/${u.id}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().user!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pengguna', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF143126))),
                  Text('Kelola akun & peran', style: TextStyle(color: Color(0xFF5B6B63), fontSize: 13)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: 'Cari nama atau email', prefixIcon: Icon(Icons.search_rounded)),
                onSubmitted: (_) => _load(),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final u = _items[i];
                              return SoftPanel(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: const IconBadge(icon: Icons.person_rounded, size: 42),
                                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${u.email}\n${roleLabel(u.role)}'),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(onPressed: () => _edit(u), icon: const Icon(Icons.edit_rounded)),
                                      if (u.id != me.id) IconButton(onPressed: () => _delete(u), icon: const Icon(Icons.delete_outline_rounded)),
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
