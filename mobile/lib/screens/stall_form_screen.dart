import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';

class StallFormScreen extends StatefulWidget {
  const StallFormScreen({super.key, this.stall});

  final Stall? stall;

  @override
  State<StallFormScreen> createState() => _StallFormScreenState();
}

class _StallFormScreenState extends State<StallFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _price;
  late final TextEditingController _capacity;
  bool _active = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final st = widget.stall;
    _name = TextEditingController(text: st?.name ?? '');
    _description = TextEditingController(text: st?.description ?? '');
    _location = TextEditingController(text: st?.location ?? '');
    _price = TextEditingController(text: st == null || st.dailyRentPrice == 0 ? '' : '${st.dailyRentPrice}');
    _capacity = TextEditingController(text: '${st?.capacity ?? 10}');
    _active = st?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _price.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'daily_rent_price': int.tryParse(_price.text.replaceAll('.', '').replaceAll(',', '')) ?? 0,
      'capacity': int.tryParse(_capacity.text.trim()) ?? 10,
      'active': _active,
    };
    try {
      final api = context.read<AuthState>().api;
      if (widget.stall == null) {
        await api.post('/api/stalls', body);
      } else {
        await api.patch('/api/stalls/${widget.stall!.id}', body);
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
      appBar: AppBar(title: Text(widget.stall == null ? 'Tambah lapak' : 'Ubah lapak')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: fieldDeco('Nama lapak'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: fieldDeco('Lokasi'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Lokasi wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: fieldDeco('Deskripsi'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: fieldDeco('Harga sewa harian (Rp)', hint: 'Opsional'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: fieldDeco('Kapasitas peserta / hari', hint: 'Mis. 10 untuk mancing bebas'),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1) return 'Minimal 1 peserta';
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lapak aktif'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
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
