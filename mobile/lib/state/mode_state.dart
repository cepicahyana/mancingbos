import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI mode only — does not change API role.
enum AppProfileMode { pemancing, pelapak }

class ModeState extends ChangeNotifier {
  AppProfileMode mode = AppProfileMode.pemancing;
  bool ready = false;

  bool get isPelapak => mode == AppProfileMode.pelapak;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile_mode') ?? 'pemancing';
    mode = raw == 'pelapak' ? AppProfileMode.pelapak : AppProfileMode.pemancing;
    ready = true;
    notifyListeners();
  }

  Future<void> setMode(AppProfileMode next) async {
    if (mode == next) return;
    mode = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_mode', next == AppProfileMode.pelapak ? 'pelapak' : 'pemancing');
    notifyListeners();
  }
}
