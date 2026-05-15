import 'dart:io';

import 'package:logging/logging.dart';

final Logger appLog = Logger('baray');
final Logger requestLog = Logger('baray.request');
final Logger dbLog = Logger('baray.db');
final Logger agendaLog = Logger('baray.agenda');
final Logger authLog = Logger('baray.auth');

/// Tamanho default que dispara rotação do `LOG_FILE`.
const int _defaultLogMaxBytes = 5 * 1024 * 1024; // 5 MiB
const int _defaultLogKeep = 3;

/// Rotaciona [current] caso o tamanho em disco seja >= [maxBytes].
///
/// Estratégia em cadeia: `app.log.<keep>` é dropado, cada `app.log.<n>`
/// vira `app.log.<n+1>`, `app.log` vira `app.log.1`, e um `app.log` vazio
/// é recriado pra próxima escrita.
///
/// Retorna `true` se rotacionou, `false` se não havia o que rotacionar
/// (arquivo ausente ou ainda dentro do limite).
bool rotateLogFile(
  File current, {
  int maxBytes = _defaultLogMaxBytes,
  int keep = _defaultLogKeep,
}) {
  if (!current.existsSync()) return false;
  if (current.lengthSync() < maxBytes) return false;

  // Solta o mais antigo antes de empurrar a cadeia pra trás.
  final oldest = File('${current.path}.$keep');
  if (oldest.existsSync()) {
    try {
      oldest.deleteSync();
    } catch (_) {
      // Se o FS não cooperar, prefere logar via stdout do que matar o request.
      // O arquivo será sobrescrito pelo rename a seguir, então não é fatal.
    }
  }

  // Empurra .{n} -> .{n+1} de trás pra frente.
  for (var i = keep - 1; i >= 1; i--) {
    final src = File('${current.path}.$i');
    if (src.existsSync()) {
      try {
        src.renameSync('${current.path}.${i + 1}');
      } catch (_) {
        // segue o baile
      }
    }
  }

  // current -> .1, recria current vazio.
  try {
    current.renameSync('${current.path}.1');
  } catch (_) {
    // Se rename falhar (lock em Windows), zera por truncate como fallback.
    current.writeAsBytesSync(const <int>[], flush: true);
    return true;
  }
  File(current.path).createSync();
  return true;
}

/// Configura o logger root. Sempre escreve em stdout via `print` (para devs
/// rodando localmente). Se `LOG_FILE` estiver definido, também faz append
/// no arquivo, com rotação por tamanho (`LOG_FILE_MAX_BYTES`, default 5 MiB,
/// até `LOG_FILE_KEEP` arquivos rotacionados, default 3).
void setupLogging() {
  final levelName = (Platform.environment['LOG_LEVEL'] ?? 'INFO').toUpperCase();
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

  final logFilePath = Platform.environment['LOG_FILE'];
  final maxBytes =
      int.tryParse(Platform.environment['LOG_FILE_MAX_BYTES'] ?? '') ??
          _defaultLogMaxBytes;
  final keep = int.tryParse(Platform.environment['LOG_FILE_KEEP'] ?? '') ??
      _defaultLogKeep;

  File? logFile;
  if (logFilePath != null && logFilePath.isNotEmpty) {
    logFile = File(logFilePath);
    final parent = logFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    if (!logFile.existsSync()) {
      logFile.createSync();
    }
  }

  Logger.root.onRecord.listen((r) {
    final ts = r.time.toUtc().toIso8601String();
    final err = r.error != null ? ' err=${r.error}' : '';
    final line = '$ts ${r.level.name.padRight(7)} ${r.loggerName} ${r.message}$err';
    // ignore: avoid_print
    print(line);
    final f = logFile;
    if (f != null) {
      try {
        rotateLogFile(f, maxBytes: maxBytes, keep: keep);
        // append + flush garante que crash não perde linhas.
        f.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      } catch (_) {
        // I/O falhando não pode derrubar o handler — stdout já tem a linha.
      }
    }
  });
}
