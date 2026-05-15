import 'dart:convert';

import 'package:empresa_server/routes/clientes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

// B-02: PUT /clientes/<id> deve propagar o novo nome para pedidos
// vinculados (cliente_id = <id>), mantendo o denormalizado `cliente_nome`
// em pedidos sincronizado quando o cliente é renomeado. Pedidos com
// cliente_id NULL (cliente desvinculado) ficam fossilizados — comportamento
// intencional, mas coberto explicitamente abaixo pra evitar regressão
// silenciosa caso alguém "limpe" o código mais tarde.

const _uuid = Uuid();

Future<Response> _put(Handler handler, String path, Object body) async {
  return await handler(Request(
    'PUT',
    Uri.parse('http://localhost$path'),
    headers: const {'content-type': 'application/json; charset=utf-8'},
    body: jsonEncode(body),
  ));
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

String _criarPedido(
  dynamic db, {
  required int lote,
  required String? clienteId,
  required String clienteNome,
}) {
  final id = _uuid.v4();
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    '''INSERT INTO pedidos (
      id, lote, cliente_id, cliente_nome, descricao, valor,
      status, urgente, criado_em, atualizado_em,
      valor_pago, sinal_pago, status_pagamento, agendamento_fixo
    ) VALUES (?, ?, ?, ?, ?, ?, 'pendente', 0, ?, ?, 0, 0, 'devendo', 0)''',
    [id, lote, clienteId, clienteNome, 'desc', 10.0, now, now],
  );
  return id;
}

void main() {
  group('B-02: PUT /clientes propaga nome para pedidos linkados', () {
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

    test('rename de cliente atualiza pedidos.cliente_nome de todos os pedidos vinculados', () async {
      final clienteId = _criarCliente(db, 'Nome Antigo');
      final p1 = _criarPedido(db, lote: 1, clienteId: clienteId, clienteNome: 'Nome Antigo');
      final p2 = _criarPedido(db, lote: 2, clienteId: clienteId, clienteNome: 'Nome Antigo');

      final resp = await _put(handler, '/$clienteId', {'nome': 'Nome Novo'});
      expect(resp.statusCode, 200, reason: 'PUT deve retornar 200');

      final rows = db.raw.select(
        'SELECT id, cliente_nome FROM pedidos WHERE id IN (?,?)',
        [p1, p2],
      );
      for (final r in rows) {
        expect(r['cliente_nome'], 'Nome Novo',
            reason: 'pedido ${r['id']} deveria refletir o novo nome');
      }
    });

    test('rename NÃO afeta pedidos com cliente_id NULL (snapshot preservado)', () async {
      final clienteId = _criarCliente(db, 'Linkado');
      final pLinkado = _criarPedido(db, lote: 1, clienteId: clienteId, clienteNome: 'Linkado');
      final pOrfao = _criarPedido(db, lote: 2, clienteId: null, clienteNome: 'Linkado');

      final resp = await _put(handler, '/$clienteId', {'nome': 'Renomeado'});
      expect(resp.statusCode, 200);

      final rLinkado = db.raw
          .select('SELECT cliente_nome FROM pedidos WHERE id=?', [pLinkado]).first;
      final rOrfao = db.raw
          .select('SELECT cliente_nome FROM pedidos WHERE id=?', [pOrfao]).first;

      expect(rLinkado['cliente_nome'], 'Renomeado',
          reason: 'pedido com cliente_id válido deve seguir o rename');
      expect(rOrfao['cliente_nome'], 'Linkado',
          reason: 'pedido órfão (cliente_id NULL) preserva snapshot');
    });

    test('rename NÃO afeta pedidos de outros clientes', () async {
      final c1 = _criarCliente(db, 'Cliente Um');
      final c2 = _criarCliente(db, 'Cliente Dois');
      final pC1 = _criarPedido(db, lote: 1, clienteId: c1, clienteNome: 'Cliente Um');
      final pC2 = _criarPedido(db, lote: 2, clienteId: c2, clienteNome: 'Cliente Dois');

      final resp = await _put(handler, '/$c1', {'nome': 'Cliente Um Renomeado'});
      expect(resp.statusCode, 200);

      final rC1 = db.raw
          .select('SELECT cliente_nome FROM pedidos WHERE id=?', [pC1]).first;
      final rC2 = db.raw
          .select('SELECT cliente_nome FROM pedidos WHERE id=?', [pC2]).first;

      expect(rC1['cliente_nome'], 'Cliente Um Renomeado');
      expect(rC2['cliente_nome'], 'Cliente Dois',
          reason: 'pedidos de outro cliente não devem ser afetados');
    });

    test('PUT sem campo "nome" no body deixa pedidos.cliente_nome inalterado', () async {
      final clienteId = _criarCliente(db, 'Estável');
      final pedidoId = _criarPedido(
        db,
        lote: 1,
        clienteId: clienteId,
        clienteNome: 'Estável',
      );

      // Atualiza só telefone — nome não vai no body.
      final resp = await _put(handler, '/$clienteId', {'telefone': '11999999999'});
      expect(resp.statusCode, 200);

      final r = db.raw
          .select('SELECT cliente_nome FROM pedidos WHERE id=?', [pedidoId]).first;
      expect(r['cliente_nome'], 'Estável',
          reason: 'sem campo nome no PUT, denormalizado fica intacto');
    });
  });
}
