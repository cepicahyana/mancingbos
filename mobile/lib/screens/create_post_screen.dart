import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'location_picker_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.forPelapak = false});

  final bool forPelapak;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _maxPhotos = 4;

  final _caption = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  PickedLocation? _location;
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    final remain = _maxPhotos - _photos.length;
    if (remain <= 0) {
      showAppError(context, 'Maksimal $_maxPhotos foto');
      return;
    }
    final files = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if (_photos.length >= _maxPhotos) break;
        _photos.add(f);
      }
    });
    if (files.length > remain && mounted) {
      showAppError(context, 'Maksimal $_maxPhotos foto, sisanya diabaikan');
    }
  }

  Future<void> _pickCamera() async {
    if (_photos.length >= _maxPhotos) {
      showAppError(context, 'Maksimal $_maxPhotos foto');
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
    if (file != null) setState(() => _photos.add(file));
  }

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      showAppError(context, 'Pilih minimal 1 foto');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthState>().api.postMultipart(
            '/api/posts',
            fields: {
              'caption': _caption.text.trim(),
              if (_location != null) 'location': _location!.name,
              if (_location != null) 'latitude': '${_location!.latitude}',
              if (_location != null) 'longitude': '${_location!.longitude}',
            },
            files: [
              for (final p in _photos) (field: 'photos', path: p.path, filename: p.name),
            ],
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user!;
    final remaining = 500 - _caption.text.length;
    final canAdd = _photos.length < _maxPhotos;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.forPelapak ? 'Upload foto lapak' : 'Buat postingan'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(_loading ? '...' : (widget.forPelapak ? 'Upload' : 'Bagikan'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          SoftPanel(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF1FA86A), AppTheme.header]),
                  ),
                  alignment: Alignment.center,
                  child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Postingan ke Komunitas IndoFish', style: TextStyle(color: AppTheme.secondary.withValues(alpha: 0.95), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftPanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Foto', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const Spacer(),
                    Text(
                      '${_photos.length}/$_maxPhotos',
                      style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_photos.isEmpty)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Material(
                      color: const Color(0xFFEEF3F0),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _pickGallery,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 52, color: AppTheme.primary),
                            SizedBox(height: 10),
                            Text('Tambah foto mancing', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
                            SizedBox(height: 4),
                            Text('Maksimal 4 foto', style: TextStyle(color: AppTheme.secondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _photos.length + (canAdd ? 1 : 0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) {
                      if (i >= _photos.length) {
                        return Material(
                          color: const Color(0xFFEEF3F0),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickGallery,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: AppTheme.primary, size: 32),
                                SizedBox(height: 4),
                                Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }
                      final photo = _photos[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(photo.path), fit: BoxFit.cover),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() => _photos.removeAt(i)),
                                  child: const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canAdd ? _pickGallery : null,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeri'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryDark,
                          side: const BorderSide(color: AppTheme.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canAdd ? _pickCamera : null,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Kamera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryDark,
                          side: const BorderSide(color: AppTheme.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftPanel(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.map_outlined, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Pin spot mancingmu di Google Maps', style: TextStyle(color: AppTheme.secondary, fontSize: 12)),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final picked = await Navigator.push<PickedLocation>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerScreen(initial: _location),
                        ),
                      );
                      if (picked != null) setState(() => _location = picked);
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: _location == null
                              ? [AppTheme.primarySoft, const Color(0xFFF4FBF7)]
                              : [const Color(0xFF0A3D32), const Color(0xFF0E5A45)],
                        ),
                        border: Border.all(color: _location == null ? AppTheme.line : Colors.transparent),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _location == null ? Colors.white : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.place_rounded,
                                color: _location == null ? AppTheme.primary : AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _location == null ? 'Pilih di Google Maps' : 'Lokasi terpasang',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: _location == null ? AppTheme.ink : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _location?.name ?? 'Cari danau, waduk, atau geser pin',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _location == null ? AppTheme.secondary : Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_location != null)
                              IconButton(
                                onPressed: () => setState(() => _location = null),
                                icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                                visualDensity: VisualDensity.compact,
                              )
                            else
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftPanel(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Caption', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.forPelapak
                      ? 'Tampilkan fasilitas, spot, dan suasana lapakmu'
                      : 'Ceritakan spot, umpan, atau hasil tangkapanmu',
                  style: const TextStyle(color: AppTheme.secondary, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _caption,
                  focusNode: _focus,
                  maxLines: 6,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: widget.forPelapak
                        ? 'Contoh: Lapak A siap event — parkir luas, toilet bersih'
                        : 'Contoh: Strike di Cirata pagi ini, umpan pelet!',
                    filled: true,
                    fillColor: AppTheme.bg,
                    counterText: '',
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        final tag = widget.forPelapak ? '#lapakmancing ' : '#mancingbos ';
                        final text = _caption.text;
                        _caption.text = text.isEmpty ? tag : '$text$tag';
                        _caption.selection = TextSelection.collapsed(offset: _caption.text.length);
                        setState(() {});
                        _focus.requestFocus();
                      },
                      child: Text(widget.forPelapak ? '#lapakmancing' : '#mancingbos'),
                    ),
                    TextButton(
                      onPressed: () {
                        final tag = widget.forPelapak ? '#sewalapak ' : '#eventmancing ';
                        final text = _caption.text;
                        _caption.text = text.isEmpty ? tag : '$text$tag';
                        _caption.selection = TextSelection.collapsed(offset: _caption.text.length);
                        setState(() {});
                        _focus.requestFocus();
                      },
                      child: Text(widget.forPelapak ? '#sewalapak' : '#eventmancing'),
                    ),
                    const Spacer(),
                    Text(
                      '$remaining',
                      style: TextStyle(
                        color: remaining < 40 ? const Color(0xFFE11D48) : AppTheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.send_rounded),
            label: Text(_loading ? 'Mengunggah...' : (widget.forPelapak ? 'Upload ke galeri lapak' : 'Bagikan postingan')),
          ),
        ],
      ),
    );
  }
}
