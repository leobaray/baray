import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api/api_client.dart';
import 'router.dart';
import 'state/theme_provider.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inter está bundlada como asset (ver pubspec.yaml). Desligar o fetch em
  // runtime evita FOUT no primeiro launch e faz o app funcionar offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('pt_BR', null);
  final url = await loadServerUrl();
  final token = await loadApiToken();
  final themeMode = await loadThemeMode();

  runApp(
    ProviderScope(
      overrides: [
        serverUrlProvider.overrideWith((ref) => url),
        apiTokenProvider.overrideWith((ref) => token),
        themeModeProvider.overrideWith((ref) => themeMode),
      ],
      child: const EmpresaApp(),
    ),
  );
}

class EmpresaApp extends ConsumerWidget {
  const EmpresaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Controle de Produção',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
