import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:empresa_server/db.dart';
import 'package:empresa_server/routes/agenda.dart';
import 'package:empresa_server/routes/clientes.dart';
import 'package:empresa_server/routes/configuracoes.dart';
import 'package:empresa_server/routes/dashboard.dart';
import 'package:empresa_server/routes/orcamento.dart';
import 'package:empresa_server/routes/pagamentos.dart';
import 'package:empresa_server/routes/pedidos.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbPath = Platform.environment['EMPRESA_DB'] ?? 'empresa.db';

  final db = Db.open(dbPath);
  print('SQLite aberto em $dbPath');

  final root = Router();
  root.get('/health', (Request req) => Response.ok(
        jsonEncode({'ok': true, 'service': 'empresa_server', 'version': '0.2.0'}),
        headers: {'content-type': 'application/json'},
      ));
  root.mount('/pedidos', pedidosRouter(db).call);
  root.mount('/clientes', clientesRouter(db).call);
  root.mount('/configuracoes', configuracoesRouter(db).call);
  root.mount('/orcamento', orcamentoRouter(db).call);
  root.mount('/pagamentos', pagamentosRouter(db).call);
  root.mount('/dashboard', dashboardRouter(db).call);
  root.mount('/agenda', agendaRouter(db).call);

  final handler = const Pipeline()
      .addMiddleware(_logRequests())
      .addMiddleware(_cors())
      .addHandler(root.call);

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Servidor rodando em http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    print('\nEncerrando...');
    await server.close(force: true);
    db.close();
    exit(0);
  });
}

Middleware _logRequests() => (inner) => (req) async {
      final sw = Stopwatch()..start();
      final res = await inner(req);
      print('${req.method} ${req.requestedUri.path} -> ${res.statusCode} (${sw.elapsedMilliseconds}ms)');
      return res;
    };

Middleware _cors() => (inner) => (req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final res = await inner(req);
      return res.change(headers: {...res.headers, ..._corsHeaders});
    };

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
};
