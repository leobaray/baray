import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:empresa_server/auth_middleware.dart';
import 'package:empresa_server/db.dart';
import 'package:empresa_server/error_middleware.dart';
import 'package:empresa_server/logger.dart';
import 'package:empresa_server/rate_limiter.dart';
import 'package:empresa_server/routes/agenda.dart';
import 'package:empresa_server/routes/clientes.dart';
import 'package:empresa_server/routes/configuracoes.dart';
import 'package:empresa_server/routes/dashboard.dart';
import 'package:empresa_server/routes/orcamento.dart';
import 'package:empresa_server/routes/pagamentos.dart';
import 'package:empresa_server/routes/pedidos.dart';

Future<void> main(List<String> args) async {
  setupLogging();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbPath = Platform.environment['EMPRESA_DB'] ?? 'empresa.db';

  final db = Db.open(dbPath);
  appLog.info('SQLite aberto em $dbPath');

  final token = resolveApiToken();
  appLog.info('API token carregado (${token.length} caracteres)');

  final allowedOrigins = _parseAllowedOrigins(
    Platform.environment['ALLOWED_ORIGINS'],
  );

  final rateLimiter = RateLimiter(
    maxFailures:
        int.tryParse(Platform.environment['AUTH_RATE_LIMIT_MAX'] ?? '') ?? 5,
    window: Duration(
      seconds: int.tryParse(
              Platform.environment['AUTH_RATE_LIMIT_WINDOW_SECONDS'] ?? '') ??
          60,
    ),
  );
  appLog.info(
    'Rate limit auth: ${rateLimiter.maxFailures} falhas / ${rateLimiter.window.inSeconds}s por IP',
  );

  final root = Router();
  root.get('/health', (Request req) {
    try {
      db.ping();
    } catch (e) {
      dbLog.severe('healthcheck falhou', e);
      return Response(
        503,
        body: jsonEncode({'ok': false, 'error': 'db indisponível'}),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return Response.ok(
      jsonEncode({'ok': true, 'service': 'empresa_server', 'version': '0.3.0'}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
  root.mount('/pedidos', pedidosRouter(db).call);
  root.mount('/clientes', clientesRouter(db).call);
  root.mount('/configuracoes', configuracoesRouter(db).call);
  root.mount('/orcamento', orcamentoRouter(db).call);
  root.mount('/pagamentos', pagamentosRouter(db).call);
  root.mount('/dashboard', dashboardRouter(db).call);
  root.mount('/agenda', agendaRouter(db).call);

  final handler = Pipeline()
      .addMiddleware(errorHandler())
      .addMiddleware(_logRequests())
      .addMiddleware(_cors(allowedOrigins))
      .addMiddleware(apiKeyAuth(token, rateLimiter: rateLimiter))
      .addHandler(root.call);

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  appLog.info('Servidor rodando em http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    appLog.info('Encerrando servidor...');
    await server.close(force: true);
    db.close();
    exit(0);
  });
}

List<String> _parseAllowedOrigins(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    // Default produção: apps mobile não enviam Origin (não disparam CORS).
    // Para uso em dev no navegador, defina ALLOWED_ORIGINS na env var.
    return const [];
  }
  return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

Middleware _logRequests() => (inner) => (req) async {
      final sw = Stopwatch()..start();
      final res = await inner(req);
      requestLog.info(
        '${req.method} ${req.requestedUri.path} -> ${res.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      return res;
    };

Middleware _cors(List<String> allowed) => (inner) => (req) async {
      final origin = req.headers['origin'];
      final corsHeaders = _buildCorsHeaders(origin, allowed);

      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final res = await inner(req);
      return res.change(headers: {...res.headers, ...corsHeaders});
    };

Map<String, String> _buildCorsHeaders(String? origin, List<String> allowed) {
  // Apps mobile (Flutter Android/iOS, Windows) NÃO enviam Origin — CORS é
  // verificado só pelo navegador. Sem origem nada precisamos liberar, mas o
  // browser de dev espera o conjunto completo.
  final allowOrigin = origin != null && allowed.contains(origin) ? origin : '';
  return {
    if (allowOrigin.isNotEmpty) 'Access-Control-Allow-Origin': allowOrigin,
    if (allowOrigin.isNotEmpty) 'Vary': 'Origin',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization, X-API-Key',
  };
}
