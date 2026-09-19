import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/mode_state.dart';
import '../widgets/app_states.dart';
import '../widgets/level_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _stallCount = 0;
  int _eventCount = 0;
  int _postCount = 0;
  bool _statsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPelapakStats());
  }

  Future<void> _loadPelapakStats() async {
    final mode = context.read<ModeState>();
    if (!mode.isPelapak) return;
    setState(() => _statsLoading = true);
    try {
      final api = context.read<AuthState>().api;
      final uid = context.read<AuthState>().user!.id;
      final stalls = await api.get('/api/stalls', query: {'mine': '1'});
      final events = await api.get('/api/events', query: {'mine': '1'});
      final posts = await api.get('/api/profiles/$uid/posts', query: {'per_page': '1'});
      if (!mounted) return;
      final meta = posts['meta'];
      final totalPosts = meta is Map ? asInt(meta['total']) : asObjectList(posts['data']).length;
      setState(() {
        _stallCount = asObjectList(stalls['data']).length;
        _eventCount = asObjectList(events['data']).length;
        _postCount = totalPosts;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final mode = context.watch<ModeState>();
    final user = auth.user!;
    final isPelapak = mode.isPelapak;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              isPelapak ? 'Profil Pelapak' : 'Profil Pemancing',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink),
            ),
            const SizedBox(height: 14),
            SoftPanel(
              padding: const EdgeInsets.all(6),
              child: SegmentedButton<AppProfileMode>(
                segments: const [
                  ButtonSegment(
                    value: AppProfileMode.pemancing,
                    label: Text('Pemancing'),
                    icon: Icon(Icons.set_meal_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: AppProfileMode.pelapak,
                    label: Text('Pelapak'),
                    icon: Icon(Icons.storefront_rounded, size: 18),
                  ),
                ],
                selected: {mode.mode},
                onSelectionChanged: (s) async {
                  await mode.setMode(s.first);
                  if (s.first == AppProfileMode.pelapak) _loadPelapakStats();
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? AppTheme.primaryDark : AppTheme.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (isPelapak) _pelapakCard(user) else _pemancingCard(user),
            const SizedBox(height: 14),
            SoftPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  if (isPelapak) ...[
                    const ListTile(
                      leading: IconBadge(icon: Icons.info_outline_rounded, size: 40),
                      title: Text('Mode bisnis lapak', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Menu bawah: Lapak · Event · Galeri · Profil'),
                    ),
                    const Divider(height: 1, color: AppTheme.line),
                  ],
                  ListTile(
                    leading: const IconBadge(icon: Icons.link_rounded, size: 40),
                    title: const Text('Alamat API', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(AppConfig.apiBaseUrl, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => auth.logout(),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pemancingCard(User user) {
    return SoftPanel(
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF3BC988), AppTheme.primaryDark]),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 14),
          Text(user.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 4),
          Text(user.email, style: const TextStyle(color: AppTheme.secondary)),
          const SizedBox(height: 12),
          Chip(
            avatar: const Icon(Icons.verified_rounded, size: 16, color: AppTheme.primaryDark),
            label: Text(roleLabel(user.role)),
          ),
          const SizedBox(height: 14),
          LevelBadge(
            level: user.level,
            tierName: user.tierName,
            points: user.points,
            pointsToNext: user.pointsToNext,
          ),
        ],
      ),
    );
  }

  Widget _pelapakCard(User user) {
    return SoftPanel(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E5A45), Color(0xFF1FA86A)],
              ),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 14),
          Text(user.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 4),
          const Text('Pemilik lapak mancing', style: TextStyle(color: AppTheme.secondary)),
          const SizedBox(height: 12),
          const Chip(
            avatar: Icon(Icons.business_center_rounded, size: 16, color: AppTheme.primaryDark),
            label: Text('Akun Pelapak'),
          ),
          const SizedBox(height: 16),
          if (_statsLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('$_stallCount', 'Lapak'),
                _stat('$_eventCount', 'Event'),
                _stat('$_postCount', 'Galeri'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.ink)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.secondary, fontSize: 12)),
      ],
    );
  }
}
