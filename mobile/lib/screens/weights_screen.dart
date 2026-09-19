import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'event_detail_screen.dart';

class WeightsScreen extends StatefulWidget {
  const WeightsScreen({super.key});

  @override
  State<WeightsScreen> createState() => _WeightsScreenState();
}

class _WeightsScreenState extends State<WeightsScreen> {
  List<FishingEvent> _events = [];
  bool _loading = true;
  String? _error;

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
      final res = await context.read<AuthState>().api.get('/api/events');
      _events = asObjectList(res['data']).map(FishingEvent.fromJson).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text('Input Berat Ikan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  Text('Pilih event untuk mencatat hasil', style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : _events.isEmpty
                          ? const EmptyView(icon: Icons.monitor_weight_rounded, title: 'Belum ada event')
                          : RefreshIndicator(
                              color: AppTheme.primary,
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                itemCount: _events.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final ev = _events[i];
                                  return SoftPanel(
                                    padding: const EdgeInsets.all(14),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const IconBadge(icon: Icons.monitor_weight_rounded),
                                      title: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      subtitle: Text(ev.location, style: const TextStyle(color: AppTheme.secondary)),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(id: ev.id))),
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
