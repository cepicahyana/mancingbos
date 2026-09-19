import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  FishingEvent? _event;
  List<Booking> _bookings = [];
  List<WeightEntry> _weights = [];
  List<EventAward> _awards = [];
  List<EventRegistration> _registrations = [];
  bool _loading = true;
  bool _awarding = false;
  bool _registering = false;
  String? _error;

  AuthState get _auth => context.read<AuthState>();
  User get _user => _auth.user!;
  ApiClient get _api => _auth.api;

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
      final res = await _api.get('/api/events/${widget.id}');
      _event = FishingEvent.fromJson(res['data'] as Map<String, dynamic>);
      final w = await _api.get('/api/events/${widget.id}/weights');
      _weights = asObjectList(w['data']).map(WeightEntry.fromJson).toList();
      final canSeeBookings = _user.isAdmin || _user.isOperator || _event!.ownerId == _user.id;
      if (canSeeBookings) {
        final b = await _api.get('/api/events/${widget.id}/bookings');
        _bookings = asObjectList(b['data']).map(Booking.fromJson).toList();
      }
      try {
        final a = await _api.get('/api/events/${widget.id}/awards');
        _awards = asObjectList(a['data']).map(EventAward.fromJson).toList();
      } catch (_) {
        _awards = [];
      }
      if (canSeeBookings) {
        try {
          final r = await _api.get('/api/events/${widget.id}/registrations');
          _registrations = asObjectList(r['data']).map(EventRegistration.fromJson).toList();
        } catch (_) {
          _registrations = [];
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_registering) return;
    final ev = _event;
    if (ev == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daftar event'),
        content: Text(
          ev.registrationFee > 0
              ? 'Biaya ${formatRp(ev.registrationFee)}.\nPembayaran via Xendit segera — status awal menunggu bayar.'
              : 'Event gratis. Lanjutkan pendaftaran?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Daftar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _registering = true);
    try {
      final res = await _api.post('/api/events/${widget.id}/register', {});
      if (!mounted) return;
      final msg = '${res['message'] ?? 'Pendaftaran berhasil'} (+5 poin)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _auth.refreshMe();
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _setRegStatus(EventRegistration reg, String status) async {
    try {
      await _api.patch('/api/registrations/${reg.id}', {'status': status});
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _book() async {
    final stall = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sewa lapak'),
        content: TextField(controller: stall, decoration: fieldDeco('Nama/nomor lapak', hint: 'Contoh: Lapak A1')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.post('/api/bookings', {'event_id': widget.id, 'stall_name': stall.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan sewa terkirim (+5 poin)')),
        );
        await _auth.refreshMe();
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _setBookingStatus(Booking b, String status) async {
    try {
      await _api.patch('/api/bookings/${b.id}', {'status': status});
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  Future<void> _awardWinners() async {
    if (_awarding) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tetapkan juara'),
        content: const Text(
          'Juara diambil dari 3 berat terbaik.\n'
          'Juara 1 = +50 poin, Juara 2 = +30, Juara 3 = +20.\n'
          'Poin hanya diberikan sekali per event.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tetapkan')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _awarding = true);
    try {
      final res = await _api.post('/api/events/${widget.id}/award-winners', {});
      final list = asObjectList(res['data']).map(EventAward.fromJson).toList();
      if (!mounted) return;
      setState(() => _awards = list);
      final newly = list.where((a) => a.awarded).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newly > 0 ? 'Juara ditetapkan (+poin ke $newly pemenang)' : 'Juara sudah ditetapkan sebelumnya')),
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _awarding = false);
    }
  }

  Future<void> _addWeight() async {
    final participants = <int, String>{
      for (final b in _bookings.where((b) => b.status == 'approved')) b.userId: b.userName,
      for (final r in _registrations.where((r) => r.status == 'paid' || r.status == 'pending_payment'))
        r.userId: r.userName,
    };
    if (participants.isEmpty) {
      showAppError(context, 'Belum ada peserta terdaftar / sewa disetujui');
      return;
    }
    int userId = participants.keys.first;
    final weight = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Input berat ikan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: userId,
                decoration: fieldDeco('Peserta'),
                items: [
                  for (final e in participants.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setLocal(() => userId = v ?? userId),
              ),
              const SizedBox(height: 12),
              TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: fieldDeco('Berat (kg)')),
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
      await _api.post('/api/weights', {
        'event_id': widget.id,
        'user_id': userId,
        'weight': double.tryParse(weight.text.replaceAll(',', '.')) ?? 0,
      });
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    }
  }

  String _placeLabel(int place) => switch (place) {
        1 => 'Juara 1',
        2 => 'Juara 2',
        3 => 'Juara 3',
        _ => 'Juara $place',
      };

  @override
  Widget build(BuildContext context) {
    final ev = _event;
    final canManage = ev != null && (_user.isAdmin || ev.ownerId == _user.id);
    final canAward = canManage || _user.isOperator;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Event'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EventFormScreen(event: ev)));
                if (ok == true) _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ev == null
                  ? const EmptyView(icon: Icons.event_busy_rounded, title: 'Event tidak ditemukan')
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        SoftPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const BrandMark(size: 52, showGlow: false),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(ev.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _info(Icons.calendar_month_rounded, DateFormat('d MMMM yyyy', 'id').format(DateTime.tryParse(ev.date) ?? DateTime.now())),
                              _info(Icons.place_outlined, ev.location),
                              _info(Icons.person_outline_rounded, 'Pemilik: ${ev.ownerName}'),
                              _info(Icons.category_outlined, categoryLabel(ev.category)),
                              _info(
                                Icons.groups_outlined,
                                ev.maxParticipants > 0
                                    ? 'Peserta: ${ev.participantsCount}/${ev.maxParticipants}'
                                    : 'Peserta: ${ev.participantsCount} (tanpa batas)',
                              ),
                              _info(Icons.payments_outlined, 'Pendaftaran: ${formatRp(ev.registrationFee)}'),
                              if (ev.stallName.isNotEmpty) _info(Icons.storefront_outlined, 'Lapak: ${ev.stallName}'),
                              const SizedBox(height: 8),
                              const StatusPill(label: 'Pembayaran: Xendit (segera)'),
                              if (ev.rentalEnabled) ...[
                                const SizedBox(height: 8),
                                StatusPill(label: ev.rentalLocked ? 'Sewa lapak terkunci (event aktif)' : 'Sewa lapak dibuka'),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                ev.description.isEmpty ? 'Tidak ada deskripsi.' : ev.description,
                                style: const TextStyle(color: AppTheme.secondary, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        if (_user.canBook && ev.ownerId != _user.id) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _registering ? null : _register,
                            icon: _registering
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.how_to_reg_rounded),
                            label: Text(ev.registrationFee > 0 ? 'Daftar · ${formatRp(ev.registrationFee)}' : 'Daftar event'),
                          ),
                        ],
                        if (ev.rentalEnabled && _user.canBook && ev.ownerId != _user.id) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: ev.rentalLocked ? null : _book,
                            icon: const Icon(Icons.storefront_rounded),
                            label: Text(ev.rentalLocked ? 'Sewa terkunci (event aktif)' : 'Sewa lapak'),
                          ),
                        ],
                        if (canManage) ...[
                          const SizedBox(height: 22),
                          const Text('Pendaftaran peserta', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 10),
                          if (_registrations.isEmpty)
                            const Text('Belum ada pendaftar.', style: TextStyle(color: AppTheme.secondary))
                          else
                            for (final reg in _registrations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SoftPanel(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    leading: const IconBadge(icon: Icons.how_to_reg_rounded, size: 40),
                                    title: Text(reg.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Text('${registrationStatusLabel(reg.status)} · ${formatRp(reg.amount)}'),
                                    trailing: reg.status == 'pending_payment'
                                        ? IconButton(
                                            tooltip: 'Tandai lunas',
                                            onPressed: () => _setRegStatus(reg, 'paid'),
                                            icon: const Icon(Icons.payments_rounded, color: AppTheme.primary),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          const SizedBox(height: 12),
                          const Text('Penyewaan lapak', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 10),
                          if (_bookings.isEmpty)
                            const Text('Belum ada permintaan sewa.', style: TextStyle(color: AppTheme.secondary))
                          else
                            for (final b in _bookings)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SoftPanel(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    leading: const IconBadge(icon: Icons.storefront_rounded, size: 40),
                                    title: Text('${b.stallName} · ${b.userName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Text(bookingStatusLabel(b.status)),
                                    trailing: b.status == 'pending'
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(onPressed: () => _setBookingStatus(b, 'approved'), icon: const Icon(Icons.check_circle_rounded, color: AppTheme.primary)),
                                              IconButton(onPressed: () => _setBookingStatus(b, 'cancelled'), icon: const Icon(Icons.cancel_rounded, color: Color(0xFFD64545))),
                                            ],
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Text('Berat ikan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                            if (_user.canInputWeight)
                              TextButton.icon(onPressed: _addWeight, icon: const Icon(Icons.add_rounded), label: const Text('Input')),
                          ],
                        ),
                        if (_weights.isEmpty)
                          const Text('Belum ada data berat.', style: TextStyle(color: AppTheme.secondary))
                        else
                          for (var i = 0; i < _weights.length; i++)
                            SoftPanel(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primarySoft,
                                  foregroundColor: AppTheme.primaryDark,
                                  child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                title: Text(_weights[i].userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                trailing: Text('${_weights[i].weight.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                              ),
                            ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Text('Juara event', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                            if (canAward)
                              TextButton.icon(
                                onPressed: _awarding || _weights.isEmpty ? null : _awardWinners,
                                icon: _awarding
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.emoji_events_rounded),
                                label: const Text('Tetapkan'),
                              ),
                          ],
                        ),
                        if (_awards.isEmpty)
                          const Text('Belum ditetapkan. Owner/operator bisa tetapkan dari ranking berat.', style: TextStyle(color: AppTheme.secondary))
                        else
                          for (final a in _awards)
                            SoftPanel(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: a.place == 1
                                      ? const Color(0xFFFFF3C4)
                                      : AppTheme.primarySoft,
                                  foregroundColor: a.place == 1
                                      ? const Color(0xFFB8860B)
                                      : AppTheme.primaryDark,
                                  child: Text('${a.place}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                title: Text(a.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(_placeLabel(a.place)),
                                trailing: Text('+${a.points} pts', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                              ),
                            ),
                      ],
                    ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.secondary))),
        ],
      ),
    );
  }
}

