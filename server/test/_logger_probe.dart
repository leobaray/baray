// Probe usado por `logger_test.dart` pra validar que `setupLogging()` lê
// `LOG_LEVEL` via `Platform.environment` em runtime. Compilado pra kernel
// e executado como subprocess em testes.
import 'package:logging/logging.dart';
import 'package:empresa_server/logger.dart';

void main() {
  setupLogging();
  // ignore: avoid_print
  print('LEVEL=${Logger.root.level.name}');
}
