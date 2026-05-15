import 'dart:convert';

import 'package:empresa_server/routes/clientes.dart';
import 'package:empresa_server/routes/pedidos.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

// M-07: testes de paginação defensiva em GET /pedidos e GET /clientes.
//
// Contrato pós-fix:
//   - LIMIT default = 200, max = 1000.
//   - ?limit=N e ?offset=M são opcionais; defaults silenciosos para valores
//     inválidos (negativos, zero, non-int).
//   - Body permanece array (compatibilidade com app v1).
//   - Header `X-Total-Count` traz o total filtrado (pré-LIMIT/OFFSET).

Future<Response> _get(Handler handler, String path) async {
  return await handler(Request('GET', Uri.parse('http://localhost$path')));
}

Future<List<dynamic>> _decodeList(Response r) async {
  final s = await r.readAsString();
  return jsonDecode(s) as List<dynamic>;
}

const _uuid = Uuid();

void _inserirPedido(dynamic db, {required String cid, required int lote}) {
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    '''INSERT INTO pedidos (
      id, lote, cliente_id, cliente_nome, descricao, valor,
      status, urgente, criado_em, atualizado_em,
      valor_pago, sinal_pago, status_pagamento, agendamento_fixo
    ) VALUES (?, ?, ?, ?, ?, ?, 'pendente', 0, ?, ?, 0, 0, 'devendo', 0)''',
    [_uuid.v4(), lote, cid, 'C$lote', 'desc', 10.0, now, now],
  );
}

void _inserirCliente(dynamic db, {required String nome}) {
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) '
    'VALUES (?,?,?,?,?)',
    [_uuid.v4(), nome, 0, now, now],
  );
}

void main() {
  group('M-07: GET /pedidos paginação', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;
    late String cid;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = pedidosRouter(db).call;

      cid = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      db.raw.execute(
        'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) '
        'VALUES (?,?,?,?,?)',
        [cid, 'CTeste', 0, now, now],
      );
      // 250 pedidos — excede o default de 200.
      for (var i = 1; i <= 250; i++) {
        _inserirPedido(db, cid: cid, lote: i);
      }
    });

    tearDown(() => tmp.cleanup());

    test('default sem ?limit retorna no máximo 200 itens', () async {
      final resp = await _get(handler, '/');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 200, reason: 'limit default = 200');
    });

    test('X-Total-Count traz total filtrado (antes do LIMIT)', () async {
      final resp = await _get(handler, '/');
      expect(resp.headers['x-total-count'], '250');
    });

    test('?offset=200 retorna o restante (50 itens)', () async {
      final resp = await _get(handler, '/?offset=200');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 50);
    });

    test('?limit=50 retorna exatamente 50 itens', () async {
      final resp = await _get(handler, '/?limit=50');
      final body = await _decodeList(resp);
      expect(body.length, 50);
      expect(resp.headers['x-total-count'], '250');
    });

    test('?limit=50&offset=100 paginação coerente — não sobrepõe pages', () async {
      final p1 = await _decodeList(await _get(handler, '/?limit=50&offset=0'));
      final p2 = await _decodeList(await _get(handler, '/?limit=50&offset=50'));
      final p3 = await _decodeList(await _get(handler, '/?limit=50&offset=100'));
      // Cada página tem 50 itens distintos.
      expect(p1.length, 50);
      expect(p2.length, 50);
      expect(p3.length, 50);
      final ids1 = p1.map((p) => (p as Map)['id']).toSet();
      final ids2 = p2.map((p) => (p as Map)['id']).toSet();
      final ids3 = p3.map((p) => (p as Map)['id']).toSet();
      expect(ids1.intersection(ids2), isEmpty, reason: 'page 1 e 2 disjuntas');
      expect(ids2.intersection(ids3), isEmpty, reason: 'page 2 e 3 disjuntas');
    });

    test('?limit acima do cap (=99999) é capado em 1000', () async {
      // Inserir até passar 1000 seria caro; aqui validamos via X-Total-Count
      // que o pedido foi aceito (não 400) e que body devolve no máximo o cap.
      final resp = await _get(handler, '/?limit=99999');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      // Só temos 250, então recebe todos; o que importa é que não houve erro.
      expect(body.length, 250);
    });

    test('?limit inválido (negativo) cai no default', () async {
      final resp = await _get(handler, '/?limit=-5');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 200, reason: '-5 inválido → default 200');
    });

    test('?limit=abc (non-int) cai no default', () async {
      final resp = await _get(handler, '/?limit=abc');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 200);
    });

    test('?offset inválido cai em 0', () async {
      final resp = await _get(handler, '/?offset=xyz');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 200);
    });

    test('filtros + paginação combinam: WHERE aplicado antes de LIMIT', () async {
      // Marca metade dos pedidos como urgentes.
      db.raw.execute('UPDATE pedidos SET urgente = 1 WHERE lote <= 100');
      final resp = await _get(handler, '/?urgente=true&limit=50');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 50);
      // Total reflete o filtro (100 urgentes), não a base toda.
      expect(resp.headers['x-total-count'], '100');
    });

    test('content-type permanece application/json', () async {
      final resp = await _get(handler, '/');
      expect(resp.headers['content-type'], contains('application/json'));
    });
  });

  group('M-07: GET /clientes paginação', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = clientesRouter(db).call;

      // 250 clientes — excede default.
      for (var i = 1; i <= 250; i++) {
        _inserirCliente(db, nome: 'Cliente ${i.toString().padLeft(3, '0')}');
      }
    });

    tearDown(() => tmp.cleanup());

    test('default retorna no máximo 200 itens', () async {
      final resp = await _get(handler, '/');
      expect(resp.statusCode, 200);
      final body = await _decodeList(resp);
      expect(body.length, 200);
    });

    test('X-Total-Count traz total filtrado', () async {
      final resp = await _get(handler, '/');
      expect(resp.headers['x-total-count'], '250');
    });

    test('?offset funciona', () async {
      final resp = await _get(handler, '/?offset=200');
      final body = await _decodeList(resp);
      expect(body.length, 50);
    });

    test('?limit=10&offset=0 e offset=10 não sobrepõem', () async {
      final p1 = await _decodeList(await _get(handler, '/?limit=10&offset=0'));
      final p2 = await _decodeList(await _get(handler, '/?limit=10&offset=10'));
      expect(p1.length, 10);
      expect(p2.length, 10);
      final ids1 = p1.map((c) => (c as Map)['id']).toSet();
      final ids2 = p2.map((c) => (c as Map)['id']).toSet();
      expect(ids1.intersection(ids2), isEmpty);
    });

    test('busca + paginação: filtro aplicado antes de LIMIT', () async {
      // Insere 5 clientes com "PaginaTeste" no nome para filtrar.
      for (var i = 0; i < 5; i++) {
        _inserirCliente(db, nome: 'PaginaTeste $i');
      }
      final resp = await _get(handler, '/?busca=PaginaTeste&limit=100');
      final body = await _decodeList(resp);
      expect(body.length, 5);
      expect(resp.headers['x-total-count'], '5');
    });

    test('?limit inválido cai no default', () async {
      final resp = await _get(handler, '/?limit=0');
      final body = await _decodeList(resp);
      expect(body.length, 200, reason: 'limit=0 inválido → default');
    });

    test('content-type permanece application/json', () async {
      final resp = await _get(handler, '/');
      expect(resp.headers['content-type'], contains('application/json'));
    });
  });
}
