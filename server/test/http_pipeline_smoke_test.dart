import 'dart:convert';

import 'package:empresa_server/auth_middleware.dart';
import 'package:empresa_server/error_middleware.dart';
import 'package:empresa_server/routes/pedidos.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

// M-05: smoke test do pipeline HTTP completo.
//
// Mota o handler igual ao `bin/server.dart`: errorHandler + apiKeyAuth +
// router. Exercita uma rota CRUD (`GET /pedidos`) e o bypass de `/health`
// pra validar auth + middleware encadeados.
//
// Cobertura intencionalmente mínima e representativa — não tenta exaurir
// payloads nem todos os verbos. A partir daqui é barato adicionar suites
// por rota usando esse mesmo padrão.

const _token = 'token-fake-pra-teste-256-bits-aaaaaaaaaaaaaaaaaaa';

Handler _buildPipeline(dynamic db) {
  final root = Router();
  root.get('/health', (Request _) {
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
  root.mount('/pedidos', pedidosRouter(db).call);

  return Pipeline()
      .addMiddleware(errorHandler())
      .addMiddleware(apiKeyAuth(_token))
      .addHandler(root.call);
}

Request _req(String method, String path, {String? token}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {
      if (token != null) 'x-api-key': token,
      'x-forwarded-for': '10.0.0.7',
    },
  );
}

void main() {
  group('M-05: pipeline HTTP (auth + router + error middleware)', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = _buildPipeline(db);
    });

    tearDown(() => tmp.cleanup());

    test('GET /pedidos com token válido → 200 + JSON array', () async {
      final resp = await handler(_req('GET', '/pedidos/', token: _token));
      expect(resp.statusCode, 200);
      expect(resp.headers['content-type'], contains('application/json'));
      final body = jsonDecode(await resp.readAsString());
      expect(body, isA<List<dynamic>>(),
          reason: 'contrato da rota é array de pedidos');
    });

    test('GET /pedidos sem token → 401 com JSON de erro', () async {
      final resp = await handler(_req('GET', '/pedidos/'));
      expect(resp.statusCode, 401);
      expect(resp.headers['content-type'], contains('application/json'));
      final body = jsonDecode(await resp.readAsString())
          as Map<String, dynamic>;
      expect(body['error'], isNotNull,
          reason: '401 deve ter mensagem estruturada');
    });

    test('GET /pedidos com token errado → 401', () async {
      final resp =
          await handler(_req('GET', '/pedidos/', token: 'token-errado'));
      expect(resp.statusCode, 401);
    });

    test('GET /health bypassa auth → 200 sem token', () async {
      final resp = await handler(_req('GET', '/health'));
      expect(resp.statusCode, 200,
          reason: '/health não pode exigir token (sonda de reverse proxy)');
      final body =
          jsonDecode(await resp.readAsString()) as Map<String, dynamic>;
      expect(body['ok'], isTrue);
    });

    test('OPTIONS bypassa auth (preflight CORS)', () async {
      final resp = await handler(_req('OPTIONS', '/pedidos/'));
      // Sem CORS middleware no smoke, ainda assim auth deve passar.
      expect(resp.statusCode, isNot(401),
          reason: 'preflight não deve ser bloqueada pela auth');
    });
  });
}
