import 'dart:convert';

import 'package:empresa_server/routes/clientes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

// B-01: DELETE /clientes/<id> deve:
//   1. Bloquear delete (409) quando há fechamentos abertos/estendidos,
//      retornando {error, count} para o app exibir warning informado.
//   2. Aceitar ?force=true e deletar tudo (cliente + fechamentos cascade)
//      dentro de uma única transação atômica.
//   3. Deletar normalmente quando não há fechamentos abertos.
//
// O efeito cascade vem do FK `cliente_fechamentos.cliente_id REFERENCES
// clientes(id) ON DELETE CASCADE` (db.dart:410) — mas só dispara se o DELETE
// do cliente for executado. O fix garante que ou (a) bloqueamos antes, ou
// (b) aceitamos a destruição com consentimento explícito via ?force.

const _uuid = Uuid();

Future<Response> _delete(Handler handler, String path) async {
  return await handler(Request('DELETE', Uri.parse('http://localhost$path')));
}

String _criarCliente(dynamic db, String nome) {
  final id = _uuid.v4();
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) '
    'VALUES (?,?,?,?,?)',
    [id, nome, 0, now, now],
  );
  return id;
}

String _criarFechamento(
  dynamic db, {
  required String clienteId,
  required int numero,
  required String status,
}) {
  final id = _uuid.v4();
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    'INSERT INTO cliente_fechamentos ('
    'id, cliente_id, numero, data_abertura, data_fechamento_prevista, '
    'status, total_pedidos, valor_total, valor_pago, criado_em, atualizado_em'
    ') VALUES (?,?,?,?,?,?,?,?,?,?,?)',
    [id, clienteId, numero, '2026-01-01', '2026-01-31', status, 0, 0.0, 0.0, now, now],
  );
  return id;
}

void main() {
  group('B-01: DELETE /clientes — transação + warning de fechamentos cascateados', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = clientesRouter(db).call;
    });

    tearDown(() => tmp.cleanup());

    test('sem fechamentos: DELETE retorna 200 e remove cliente', () async {
      final id = _criarCliente(db, 'Sem Fechamentos');
      final resp = await _delete(handler, '/$id');
      expect(resp.statusCode, 200);
      final remaining = db.raw.select('SELECT id FROM clientes WHERE id=?', [id]);
      expect(remaining, isEmpty);
    });

    test('com fechamento aberto e SEM force: retorna 409 e cliente permanece', () async {
      final id = _criarCliente(db, 'Tem Aberto');
      _criarFechamento(db, clienteId: id, numero: 1, status: 'aberto');
      _criarFechamento(db, clienteId: id, numero: 2, status: 'estendido');
      _criarFechamento(db, clienteId: id, numero: 3, status: 'fechado');

      final resp = await _delete(handler, '/$id');
      expect(resp.statusCode, 409,
          reason: 'cliente com fechamentos abertos não deve ser deletado sem force');

      final body = jsonDecode(await resp.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('fechamentos abertos'));
      expect(body['count'], 2,
          reason: 'count deve incluir aberto+estendido, não fechado');

      final remaining = db.raw.select('SELECT id FROM clientes WHERE id=?', [id]);
      expect(remaining, isNotEmpty, reason: 'cliente deve permanecer após 409');
      final fechs = db.raw.select(
        'SELECT id FROM cliente_fechamentos WHERE cliente_id=?', [id]);
      expect(fechs.length, 3, reason: 'fechamentos devem permanecer intactos');
    });

    test('com fechamento aberto e ?force=true: deleta cliente + cascade dos fechamentos', () async {
      final id = _criarCliente(db, 'Force');
      _criarFechamento(db, clienteId: id, numero: 1, status: 'aberto');
      _criarFechamento(db, clienteId: id, numero: 2, status: 'fechado');

      final resp = await _delete(handler, '/$id?force=true');
      expect(resp.statusCode, 200);

      final remaining = db.raw.select('SELECT id FROM clientes WHERE id=?', [id]);
      expect(remaining, isEmpty, reason: 'cliente deve ter sido deletado');
      final fechs = db.raw.select(
        'SELECT id FROM cliente_fechamentos WHERE cliente_id=?', [id]);
      expect(fechs, isEmpty, reason: 'fechamentos devem cascatear');
    });

    test('com apenas fechamentos fechados: DELETE retorna 200 sem force (count=0)', () async {
      final id = _criarCliente(db, 'Histórico Fechado');
      _criarFechamento(db, clienteId: id, numero: 1, status: 'fechado');
      _criarFechamento(db, clienteId: id, numero: 2, status: 'fechado');

      final resp = await _delete(handler, '/$id');
      expect(resp.statusCode, 200,
          reason: 'fechamentos só com status=fechado não bloqueiam delete');

      final fechs = db.raw.select(
        'SELECT id FROM cliente_fechamentos WHERE cliente_id=?', [id]);
      expect(fechs, isEmpty, reason: 'cascade ON DELETE remove os fechados também');
    });

    test('cliente inexistente: 404 mesmo com ?force=true', () async {
      final resp = await _delete(handler, '/nao-existe?force=true');
      expect(resp.statusCode, 404);
    });
  });
}
