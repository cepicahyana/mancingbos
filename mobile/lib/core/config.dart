import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://127.0.0.1:8080';
  }
}

String roleLabel(String role) {
  return switch (role) {
    'user' => 'Pencinta Mancing',
    'owner' => 'Pemilik Lapak',
    'operator' => 'Operator',
    'admin' => 'Admin',
    'superadmin' => 'Superadmin',
    _ => role,
  };
}

String bookingStatusLabel(String status) {
  return switch (status) {
    'pending' => 'Menunggu',
    'approved' => 'Disetujui',
    'cancelled' => 'Dibatalkan',
    _ => status,
  };
}

String categoryLabel(String category) {
  return switch (category) {
    'galatama' => 'Galatama',
    'galapung' => 'Galapung',
    'kilogebrus' => 'Kilogebrus',
    'casting' => 'Casting',
    'feeder' => 'Feeder',
    'beregu' => 'Beregu',
    // legacy
    'lomba_berat' => 'Kilogebrus',
    'lomba_jumlah' => 'Galatama',
    'santuy' => 'Galapung',
    'team' => 'Beregu',
    _ => category,
  };
}

String registrationStatusLabel(String status) {
  return switch (status) {
    'pending_payment' => 'Menunggu bayar',
    'paid' => 'Lunas',
    'cancelled' => 'Dibatalkan',
    _ => status,
  };
}

String formatRp(int amount) {
  if (amount <= 0) return 'Gratis';
  final s = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

