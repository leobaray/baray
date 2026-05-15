import 'dart:io';

import 'package:empresa_server/db.dart';

/// Cria um DB temporário em memória, roda migrations e devolve o handle.
/// O caller é responsável por chamar `cleanup()` ao final.
({Db db, void Function() cleanup}) novoDb({String? path}) {
  final dbPath = path ?? _tmpDbPath();
  final db = Db.open(dbPath);
  return (
    db: db,
    cleanup: () {
      db.close();
      if (dbPath != ':memory:') {
        for (final ext in ['', '-wal', '-shm', '-journal']) {
          final f = File('$dbPath$ext');
          if (f.existsSync()) {
            try {
              f.deleteSync();
            } catch (_) {
              // Tudo bem se o WAL ainda estiver locked — vai sumir no GC.
            }
          }
        }
      }
    },
  );
}

String _tmpDbPath() {
  final dir = Directory.systemTemp.createTempSync('baray_test_');
  return '${dir.path}${Platform.pathSeparator}empresa.db';
}
