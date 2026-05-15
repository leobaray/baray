// Probe usado por `b03_logger_file_rotation_test.dart` pra validar que
// `setupLogging()` escreve no `LOG_FILE` em runtime. Compilado pra kernel
// e executado como subprocess.
import 'package:empresa_server/logger.dart';

void main() {
  setupLogging();
  appLog.info('linha um');
  appLog.warning('linha dois');
  // ignore: avoid_print
  print('PROBE_DONE');
}
