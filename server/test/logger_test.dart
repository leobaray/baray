import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Probe (`test/_logger_probe.dart`) é compilado pra kernel uma única vez no
/// `setUpAll`. Subprocess executa o kernel pra validar leitura de LOG_LEVEL
/// via Platform.environment em runtime. Pré-compilar evita disputa
/// concorrente pelo cache de native assets (sqlite3.dll) entre múltiplos
/// `dart run` em paralelo.
late Directory _kernelDir;
late String _probeKernel;

Future<void> _buildProbe() async {
  _kernelDir = await Directory.systemTemp.createTemp('baray_logger_probe_');
  _probeKernel = '${_kernelDir.path}/probe.dill';
  final probeSrc = 'test/_logger_probe.dart';

  final compile = await Process.run(
    Platform.resolvedExecutable,
    ['compile', 'kernel', probeSrc, '-o', _probeKernel],
    workingDirectory: Directory.current.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(
    compile.exitCode,
    0,
    reason: 'compile kernel falhou: ${compile.stdout}\n${compile.stderr}',
  );
}

Future<String> _captureLevel({Map<String, String>? extraEnv}) async {
  final env = <String, String>{
    ...Platform.environment,
  };
  // Default: começamos sem LOG_LEVEL herdado pra teste de default ser limpo.
  env.remove('LOG_LEVEL');
  if (extraEnv != null) {
    env.addAll(extraEnv);
  }

  final result = await Process.run(
    Platform.resolvedExecutable,
    [_probeKernel],
    environment: env,
    workingDirectory: Directory.current.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(
    result.exitCode,
    0,
    reason: 'probe falhou: stdout=${result.stdout}\nstderr=${result.stderr}',
  );

  final stdout = result.stdout as String;
  final match = RegExp(r'LEVEL=(\w+)').firstMatch(stdout);
  expect(match, isNotNull, reason: 'probe stdout: $stdout');
  return match!.group(1)!;
}

void main() {
  group('setupLogging — LOG_LEVEL via Platform.environment (runtime)', () {
    setUpAll(_buildProbe);
    tearDownAll(() async {
      if (await _kernelDir.exists()) {
        await _kernelDir.delete(recursive: true);
      }
    });

    test('default é INFO quando LOG_LEVEL não está setado', () async {
      final level = await _captureLevel();
      expect(level, 'INFO');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('LOG_LEVEL=FINE eleva nível em runtime', () async {
      final level = await _captureLevel(extraEnv: {'LOG_LEVEL': 'FINE'});
      expect(level, 'FINE');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('LOG_LEVEL=SEVERE é respeitado em runtime', () async {
      final level = await _captureLevel(extraEnv: {'LOG_LEVEL': 'SEVERE'});
      expect(level, 'SEVERE');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('valor inválido cai pro default INFO', () async {
      final level = await _captureLevel(extraEnv: {'LOG_LEVEL': 'NAO_EXISTE'});
      expect(level, 'INFO');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
