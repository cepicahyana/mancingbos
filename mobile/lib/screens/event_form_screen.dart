import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final FishingEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _maxParticipants;
  late final TextEditingController _fee;
  DateTime _date = DateTime.now();
  bool _rental = false;
  bool _loading = false;
  String _category = 'galatama';
  int? _stallId;
  List<Stall> _stalls = [];

  static const _categories = [
    ('galatama', 'Galatama'),
    ('galapung', 'Galapung'),
    ('kilogebrus', 'Kilogebrus'),
    ('casting', 'Casting'),
    ('feeder', 'Feeder'),
    ('beregu', 'Beregu'),
  ];

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    _title = TextEditingController(text: ev?.title ?? '');
    _description = TextEditingController(text: ev?.description ?? '');
    _location = TextEditingController(text: ev?.location ?? '');
    _maxParticipants = TextEditingController(
      text: ev == null || ev.maxParticipants == 0 ? '' : '${ev.maxParticipants}',
    );
    _fee = TextEditingController(
      text: ev == null || ev.registrationFee == 0 ? '' : '${ev.registrationFee}',
    );
    _rental = ev?.rentalEnabled ?? false;
    _category = ev?.category ?? 'galatama';
    _stallId = ev?.stallId;
    _date = DateTime.tryParse(ev?.date ?? '') ?? DateTime.now();
    _loadStalls();
  }

  Future<void> _loadStalls() async {
    try {
      final api = context.read<AuthState>().api;
      final res = await api.get('/api/stalls', query: {'mine': '1'});
      if (!mounted) return;
      setState(() {
        _stalls = asObjectList(res['data']).map(Stall.fromJson).toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _maxParticipants.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_location.text.trim().isEmpty && _stallId == null) {
      showAppError(context, 'Lokasi atau lapak wajib diisi');
      return;
    }
    setState(() => _loading = true);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'date': _date.toIso8601String().substring(0, 10),
      'location': _location.text.trim(),
      'rental_enabled': _rental,
      'category': _category,
      'max_participants': int.tryParse(_maxParticipants.text.trim()) ?? 0,
      'registration_fee': int.tryParse(_fee.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0,
      if (_stallId != null) 'stall_id': _stallId,
    };
    try {
      final api = context.read<AuthState>().api;
      if (widget.event == null) {
        await api.post('/api/events', body);
      } else {
        await api.patch('/api/events/${widget.event!.id}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? 'Buat Event' : 'Ubah Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _title,
                decoration: fieldDeco('Judul event'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: fieldDeco('Deskripsi'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                // ignore: deprecated_member_use
                value: _stallId,
                decoration: fieldDeco('Lapak (opsional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tanpa lapak')),
                  for (final st in _stalls)
                    DropdownMenuItem<int?>(value: st.id, child: Text(st.name)),
                ],
                onChanged: (v) {
                  setState(() {
                    _stallId = v;
                    if (v != null) {
                      final st = _stalls.where((e) => e.id == v).firstOrNull;
                      if (st != null && _location.text.trim().isEmpty) {
                        _location.text = st.location;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: fieldDeco('Lokasi'),
                validator: (v) {
                  if ((v == null || v.trim().isEmpty) && _stallId == null) {
                    return 'Lokasi wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _category,
                decoration: fieldDeco('Kategori kompetisi'),
                items: [
                  for (final c in _categories) DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'galatama'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxParticipants,
                keyboardType: TextInputType.number,
                decoration: fieldDeco('Jumlah peserta (kuota)', hint: '0 = tanpa batas'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: fieldDeco('Harga pendaftaran (Rp)', hint: '0 = gratis · bayar via Xendit nanti'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal'),
                subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                    helpText: 'Pilih tanggal event',
                    cancelText: 'Batal',
                    confirmText: 'Pilih',
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Buka sewa lapak'),
                subtitle: const Text('Tidak bisa disewa saat event aktif di lapak yang sama'),
                value: _rental,
                onChanged: (v) => setState(() => _rental = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Pembayaran pendaftaran: Xendit (segera)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _save,
                child: Text(_loading ? 'Menyimpan...' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
