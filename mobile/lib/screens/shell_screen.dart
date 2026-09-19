import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/mode_state.dart';
import 'bookings_screen.dart';
import 'events_screen.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';
import 'stalls_screen.dart';
import 'users_screen.dart';
import 'weights_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon, this.builder);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  bool? _lastPelapak;

  List<_NavItem> _pemancingItems(User user) {
    return [
      _NavItem('Event', Icons.water_rounded, Icons.water, (_) => const EventsScreen()),
      _NavItem('Feed', Icons.photo_camera_outlined, Icons.photo_camera_rounded, (_) => const FeedScreen()),
      if (user.canBook)
        _NavItem('Harian', Icons.storefront_outlined, Icons.storefront_rounded, (_) => const BookingsScreen()),
      if (user.canInputWeight)
        _NavItem('Berat', Icons.monitor_weight_outlined, Icons.monitor_weight_rounded, (_) => const WeightsScreen()),
      if (user.isAdmin)
        _NavItem('User', Icons.manage_accounts_outlined, Icons.manage_accounts_rounded, (_) => const UsersScreen()),
      _NavItem('Profil', Icons.person_outline_rounded, Icons.person_rounded, (_) => const ProfileScreen()),
    ];
  }

  List<_NavItem> _pelapakItems(User user) {
    return [
      _NavItem('Lapak', Icons.storefront_outlined, Icons.storefront_rounded, (_) => const StallsScreen()),
      _NavItem('Event', Icons.event_note_outlined, Icons.event_note_rounded, (_) => const EventsScreen(mine: true)),
      _NavItem(
        'Galeri',
        Icons.photo_library_outlined,
        Icons.photo_library_rounded,
        (_) => const FeedScreen(mineOnly: true, title: 'Galeri Lapak'),
      ),
      if (user.canInputWeight)
        _NavItem('Berat', Icons.monitor_weight_outlined, Icons.monitor_weight_rounded, (_) => const WeightsScreen()),
      if (user.isAdmin)
        _NavItem('User', Icons.manage_accounts_outlined, Icons.manage_accounts_rounded, (_) => const UsersScreen()),
      _NavItem('Profil', Icons.person_outline_rounded, Icons.person_rounded, (_) => const ProfileScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user!;
    final isPelapak = context.watch<ModeState>().isPelapak;
    if (_lastPelapak != null && _lastPelapak != isPelapak) {
      _index = 0;
    }
    _lastPelapak = isPelapak;

    final items = isPelapak ? _pelapakItems(user) : _pemancingItems(user);
    if (_index >= items.length) _index = 0;

    return Scaffold(
      body: KeyedSubtree(
        key: ValueKey('shell_${isPelapak}_$_index'),
        child: items[_index].builder(context),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: isPelapak ? const Color(0xFFD4E8DC) : AppTheme.line)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
