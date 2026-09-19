import 'package:flutter_test/flutter_test.dart';
import 'package:indofish/core/config.dart';

void main() {
  test('label peran sesuai dokumentasi', () {
    expect(roleLabel('user'), 'Pencinta Mancing');
    expect(roleLabel('owner'), 'Pemilik Lapak');
    expect(roleLabel('operator'), 'Operator');
    expect(bookingStatusLabel('pending'), 'Menunggu');
  });
}
