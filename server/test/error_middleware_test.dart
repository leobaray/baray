import 'dart:convert';

import 'package:empresa_server/error_middleware.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Response _ok(Request _) =>
    Response.ok('ok', headers: {'content-type': 'text/plain'});

Response _throwsState(Request _) {
  throw StateError('detalhe interno secreto: db://user:pwd@host');
}

Future<Response> _throwsAsyncFormat(Request _) async {
  await Future<void>.delayed(Duration.zero);
  throw const FormatException('schema-drift: coluna preco_centavos');
}

Response _throwsHijack(Request _) {
  throw const HijackException();
}

void main() {
  group('errorHandler middleware (M-03)', () {
    test('passa resposta normal sem alterar quando inner não lança', () async {
      final wrapped = errorHandler()(_ok);
      final res = await wrapped(Request('GET', Uri.parse('http://x/test')));

      expect(res.statusCode, 200);
      expect(await res.readAsString(), 'ok');
    });

    test('captura exception não-tratada e retorna 500 com JSON genérico',
        () async {
      final wrapped = errorHandler()(_throwsState);
      final res = await wrapped(Request('GET', Uri.parse('http://x/bomba')));

      expect(res.statusCode, 500);
      expect(
        res.headers['content-type'],
        contains('application/json'),
      );

      final body = await res.readAsString();
      // body deve ser JSON parseável e NÃO conter detalhes internos
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['error'], 'internal_server_error');
      expect(body, isNot(contains('StateError')));
      expect(body, isNot(contains('detalhe interno secreto')));
      expect(body, isNot(contains('db://')));
    });

    test('captura exception async (Future.error) e retorna 500 genérico',
        () async {
      final wrapped = errorHandler()(_throwsAsyncFormat);
      final res = await wrapped(Request('GET', Uri.parse('http://x/async')));

      expect(res.statusCode, 500);
      final body = await res.readAsString();
      expect(body, isNot(contains('FormatException')));
      expect(body, isNot(contains('preco_centavos')));
      expect(jsonDecode(body), {'error': 'internal_server_error'});
    });

    test('rethrow de HijackException (não engole sinal de hijack do shelf)',
        () async {
      final wrapped = errorHandler()(_throwsHijack);
      expect(
        () => wrapped(Request('GET', Uri.parse('http://x/hijack'))),
        throwsA(isA<HijackException>()),
      );
    });
  });
}
