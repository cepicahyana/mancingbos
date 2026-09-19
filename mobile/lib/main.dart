import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'state/auth_state.dart';
import 'state/mode_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');
  final auth = AuthState(ApiClient());
  final mode = ModeState();
  await Future.wait([auth.bootstrap(), mode.bootstrap()]);
  runApp(IndoFishApp(auth: auth, mode: mode));
}

class IndoFishApp extends StatelessWidget {
  const IndoFishApp({super.key, required this.auth, required this.mode});

  final AuthState auth;
  final ModeState mode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: mode),
      ],
      child: MaterialApp(
        title: 'IndoFish',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('id'),
        supportedLocales: const [Locale('id'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Consumer<AuthState>(
          builder: (_, state, _) {
            if (!state.ready) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return state.user == null ? const LoginScreen() : const ShellScreen();
          },
        ),
      ),
    );
  }
}
