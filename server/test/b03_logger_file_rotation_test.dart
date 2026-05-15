import 'dart:io';

import 'package:empresa_server/logger.dart';
import 'package:test/test.dart';

// B-03: setupLogging escrevia só em stdout via print(); sem rotação, o stdout
// redirecionado para arquivo em produção crescia indefinidamente.
//
// Fix: helper `rotateLogFile` (unit) + integração via LOG_FILE/LOG_FILE_MAX_BYTES
// no setupLogging. Stdout continua sendo escrito (devs em terminal).
//
// Suite cobre:
//   1. rotateLogFile: arquivo abaixo do limite não rotaciona.
//   2. rotateLogFile: ao cruzar o limite, current vira .1 (e fica vazio).
//   3. rotateLogFile: rotações sucessivas .1->.2->.3, .3 é dropado.
//   4. rotateLogFile: noop quando o arquivo não existe.
//   5. setupLogging integration: LOG_FILE escreve linhas no arquivo.

Directory _tmpDir() {
  return Directory.systemTemp.createTempSync('baray_logger_b03_');
}

void main() {
  group('B-03 rotateLogFile (unit)', () {
    late Directory dir;

    setUp(() {
      dir = _tmpDir();
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('arquivo abaixo do limite não é rotacionado', () {
      final f = File('${dir.path}${Platform.pathSeparator}app.log');
      f.writeAsStringSync('linha pequena\n');
      final originalSize = f.lengthSync();

      final rotated = rotateLogFile(f, maxBytes: 1024, keep: 3);

      expect(rotated, isFalse);
      expect(f.existsSync(), isTrue);
      expect(f.lengthSync(), originalSize);
      expect(File('${f.path}.1').existsSync(), isFalse);
    });

    test('ao cruzar o limite, current vira .1 e current fica vazio', () {
      final f = File('${dir.path}${Platform.pathSeparator}app.log');
      final payload = List<int>.filled(200, 65); // 200 bytes de 'A'
      f.writeAsBytesSync(payload);
      expect(f.lengthSync(), 200);

      final rotated = rotateLogFile(f, maxBytes: 100, keep: 3);

      expect(rotated, isTrue);
      expect(f.existsSync(), isTrue,
          reason: 'current recriado vazio após rotação');
      expect(f.lengthSync(), 0);
      final r1 = File('${f.path}.1');
      expect(r1.existsSync(), isTrue);
      expect(r1.lengthSync(), 200);
    });

    test('rotações sucessivas: .1->.2->.3 e .3 antigo é dropado', () {
      final base = '${dir.path}${Platform.pathSeparator}app.log';
      final f = File(base);

      // Primeira rotação: gera .1
      f.writeAsBytesSync(List<int>.filled(200, 49)); // '1'
      rotateLogFile(f, maxBytes: 100, keep: 3);
      expect(File('$base.1').readAsBytesSync().first, 49);

      // Segunda rotação: .1 vira .2, current vira .1
      f.writeAsBytesSync(List<int>.filled(200, 50)); // '2'
      rotateLogFile(f, maxBytes: 100, keep: 3);
      expect(File('$base.1').readAsBytesSync().first, 50);
      expect(File('$base.2').readAsBytesSync().first, 49);

      // Terceira rotação: cadeia completa
      f.writeAsBytesSync(List<int>.filled(200, 51)); // '3'
      rotateLogFile(f, maxBytes: 100, keep: 3);
      expect(File('$base.1').readAsBytesSync().first, 51);
      expect(File('$base.2').readAsBytesSync().first, 50);
      expect(File('$base.3').readAsBytesSync().first, 49);

      // Quarta rotação: .3 antigo deve ser dropado (não vira .4)
      f.writeAsBytesSync(List<int>.filled(200, 52)); // '4'
      rotateLogFile(f, maxBytes: 100, keep: 3);
      expect(File('$base.1').readAsBytesSync().first, 52);
      expect(File('$base.2').readAsBytesSync().first, 51);
      expect(File('$base.3').readAsBytesSync().first, 50);
      expect(File('$base.4').existsSync(), isFalse,
          reason: 'keep=3 limita a .3 inclusive');
    });

    test('noop quando o arquivo não existe', () {
      final f = File('${dir.path}${Platform.pathSeparator}nao_existe.log');
      expect(f.existsSync(), isFalse);

      final rotated = rotateLogFile(f, maxBytes: 100, keep: 3);

      expect(rotated, isFalse);
      expect(f.existsSync(), isFalse);
    });
  });

  group('B-03 setupLogging com LOG_FILE (subprocess integration)', () {
    late Directory dir;
    late Directory kernelDir;
    late String probeKernel;

    setUpAll(() async {
      // Mesma estratégia de `_logger_probe.dart`: pré-compila kernel uma vez
      // pra evitar disputa pelo cache de native assets em paralelo.
      kernelDir = Directory.systemTemp.createTempSync('baray_logger_b03_kernel_');
      probeKernel = '${kernelDir.path}${Platform.pathSeparator}probe.dill';
      final compile = await Process.run(
        Platform.resolvedExecutable,
        ['compile', 'kernel', 'test/_logger_file_probe.dart', '-o', probeKernel],
        workingDirectory: Directory.current.path,
      );
      expect(compile.exitCode, 0,
          reason: 'compile kernel falhou: ${compile.stdout}\n${compile.stderr}');
    });

    tearDownAll(() {
      if (kernelDir.existsSync()) {
        try {
          kernelDir.deleteSync(recursive: true);
        } catch (_) {
          // tudo bem se Windows ainda segurar lock
        }
      }
    });

    setUp(() {
      dir = _tmpDir();
    });

    tearDown(() {
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {
          // tudo bem se Windows ainda segurar lock
        }
      }
    });

    test('LOG_FILE escreve linhas no arquivo (além do stdout)', () async {
      final logPath = '${dir.path}${Platform.pathSeparator}app.log';

      final env = <String, String>{
        ...Platform.environment,
        'LOG_FILE': logPath,
      };

      final result = await Process.run(
        Platform.resolvedExecutable,
        [probeKernel],
        environment: env,
        workingDirectory: Directory.current.path,
      );

      expect(
        result.exitCode,
        0,
        reason: 'subprocess falhou: ${result.stdout}\n${result.stderr}',
      );
      expect(
        '${result.stdout}',
        contains('PROBE_DONE'),
        reason: 'probe não terminou com sucesso',
      );

      final logFile = File(logPath);
      expect(logFile.existsSync(), isTrue,
          reason: 'LOG_FILE devia ter sido criado');
      final content = logFile.readAsStringSync();
      expect(content, contains('linha um'));
      expect(content, contains('linha dois'));
      expect(content, contains('INFO'));
      expect(content, contains('WARNING'));
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
