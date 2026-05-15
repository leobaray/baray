import 'package:logging/logging.dart';

final Logger appLog = Logger('baray');
final Logger requestLog = Logger('baray.request');
final Logger dbLog = Logger('baray.db');
final Logger agendaLog = Logger('baray.agenda');
final Logger authLog = Logger('baray.auth');

void setupLogging() {
  final levelName = (const String.fromEnvironment('LOG_LEVEL')).toUpperCase();
  Logger.root.level = switch (levelName) {
    'SEVERE' => Level.SEVERE,
    'WARNING' => Level.WARNING,
    'INFO' => Level.INFO,
    'CONFIG' => Level.CONFIG,
    'FINE' => Level.FINE,
    'FINER' => Level.FINER,
    'FINEST' => Level.FINEST,
    _ => Level.INFO,
  };
  Logger.root.onRecord.listen((r) {
    final ts = r.time.toUtc().toIso8601String();
    final err = r.error != null ? ' err=${r.error}' : '';
    // ignore: avoid_print
    print('$ts ${r.level.name.padRight(7)} ${r.loggerName} ${r.message}$err');
  });
}
