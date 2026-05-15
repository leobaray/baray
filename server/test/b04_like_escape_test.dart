import 'dart:convert';

import 'package:empresa_server/routes/clientes.dart';
import 'package:empresa_server/routes/pedidos.dart';
import 'package:empresa_server/sql_like.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

// B-04: termos de busca com `%` ou `_` viravam wildcards e retornavam matches
// indevidos. Fix: helper `escapeLikePattern` + cláusula `LIKE ? ESCAPE '\'`
// nas rotas de busca.
//
// Suite cobre:
//   1. `escapeLikePattern` (unit) — escapa `\`, `%`, `_` na ordem certa e
//      é idempotente p/ chars que não exigem escape.
//   2. GET /clientes ?busca=… — `_` e `%` no termo só matcham literais.
//   3. GET /pedidos ?busca=… e ?cliente=… — idem.

Future<Response> _get(Handler handler, String path) async {
  return await handler(Request('GET', Uri.parse('http://localhost$path')));
}

Future<List<dynamic>> _decodeList(Response r) async {
  final s = await r.readAsString();
  return jsonDecode(s) as List<dynamic>;
}

const _uuid = Uuid();

void _inserirCliente(dynamic db, {required String nome, String? telefone}) {
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    'INSERT INTO clientes (id, nome, telefone, fechamento_ativo, criado_em, atualizado_em) '
    'VALUES (?,?,?,?,?,?)',
    [_uuid.v4(), nome, telefone, 0, now, now],
  );
}

void _inserirPedido(
  dynamic db, {
  required String cid,
  required String clienteNome,
  required String descricao,
  String? observacao,
  required int lote,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  db.raw.execute(
    '''INSERT INTO pedidos (
      id, lote, cliente_id, cliente_nome, descricao, observacao, valor,
      status, urgente, criado_em, atualizado_em,
      valor_pago, sinal_pago, status_pagamento, agendamento_fixo
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pendente', 0, ?, ?, 0, 0, 'devendo', 0)''',
    [_uuid.v4(), lote, cid, clienteNome, descricao, observacao, 10.0, now, now],
  );
}

void main() {
  group('B-04 escapeLikePattern (unit)', () {
    test('escapa `%` com `\\%`', () {
      expect(escapeLikePattern('50%'), r'50\%');
      expect(escapeLikePattern('%a%b%'), r'\%a\%b\%');
    });

    test('escapa `_` com `\\_`', () {
      expect(escapeLikePattern('arq_test'), r'arq\_test');
      expect(escapeLikePattern('_'), r'\_');
    });

    test('escapa `\\` antes de tudo para evitar dupla-substituição', () {
      // Backslash sozinho vira \\
      expect(escapeLikePattern(r'\'), r'\\');
      // Combinação `\%` na entrada vira `\\\%` (backslash escapado, depois %).
      expect(escapeLikePattern(r'\%'), r'\\\%');
      // `\_` idem.
      expect(escapeLikePattern(r'\_'), r'\\\_');
    });

    test('strings sem metacaracteres passam inalteradas', () {
      expect(escapeLikePattern('Joao Silva'), 'Joao Silva');
      expect(escapeLikePattern(''), '');
      expect(escapeLikePattern('Acentos áéíóú ç'), 'Acentos áéíóú ç');
    });
  });

  group('B-04 GET /clientes ?busca= não trata `_`/`%` como wildcard', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = clientesRouter(db).call;

      // Cenário: três clientes com nomes que ilustram o bug.
      _inserirCliente(db, nome: 'arq_test');   // literal com `_`
      _inserirCliente(db, nome: 'arq1test');   // só matcharia se `_` fosse wildcard
      _inserirCliente(db, nome: 'arqXtest');   // idem
      _inserirCliente(db, nome: '50% off');    // literal com `%`
      _inserirCliente(db, nome: '50 off');     // antes do fix, `%` matchava qualquer coisa
    });

    tearDown(() => tmp.cleanup());

    test('busca por "arq_test" só retorna o registro literal', () async {
      final r = await _get(handler, '/?busca=arq_test');
      expect(r.statusCode, 200);
      final body = await _decodeList(r);
      final nomes = body.map((c) => c['nome'] as String).toList()..sort();
      expect(nomes, ['arq_test']);
    });

    test('busca por "50%" só retorna o registro literal', () async {
      // Termo precisa ser URL-encoded (`%` => `%25`) pra chegar ao server
      // como literal.
      final r = await _get(handler, '/?busca=50%25');
      expect(r.statusCode, 200);
      final body = await _decodeList(r);
      final nomes = body.map((c) => c['nome'] as String).toList()..sort();
      expect(nomes, ['50% off']);
    });

    test('busca por "arq" (sem metacaracter) ainda matcha todos os "arq*"', () async {
      final r = await _get(handler, '/?busca=arq');
      final body = await _decodeList(r);
      final nomes = body.map((c) => c['nome'] as String).toSet();
      expect(nomes, {'arq_test', 'arq1test', 'arqXtest'});
    });
  });

  group('B-04 GET /pedidos ?busca= e ?cliente= não tratam `_`/`%` como wildcard', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Handler handler;
    late String cidA;
    late String cidB;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      handler = pedidosRouter(db).call;

      cidA = _uuid.v4();
      cidB = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      // Dois clientes com nomes que diferem só pelo `_`
      db.raw.execute(
        'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) '
        'VALUES (?,?,?,?,?)',
        [cidA, 'cli_a', 0, now, now],
      );
      db.raw.execute(
        'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) '
        'VALUES (?,?,?,?,?)',
        [cidB, 'cliXa', 0, now, now],
      );

      _inserirPedido(db, cid: cidA, clienteNome: 'cli_a', descricao: 'arq_test', lote: 1);
      _inserirPedido(db, cid: cidB, clienteNome: 'cliXa', descricao: 'arqXtest', lote: 2);
      _inserirPedido(db, cid: cidA, clienteNome: 'cli_a', descricao: 'banner 50% off', lote: 3);
      _inserirPedido(db, cid: cidA, clienteNome: 'cli_a', descricao: 'banner 50 off',  lote: 4);
    });

    tearDown(() => tmp.cleanup());

    test('busca=arq_test só matcha o lote literal', () async {
      final r = await _get(handler, '/?busca=arq_test');
      final body = await _decodeList(r);
      final lotes = body.map((p) => p['lote'] as int).toList()..sort();
      expect(lotes, [1]);
    });

    test('busca=50%25 só matcha o lote literal', () async {
      final r = await _get(handler, '/?busca=50%25');
      final body = await _decodeList(r);
      final lotes = body.map((p) => p['lote'] as int).toList()..sort();
      expect(lotes, [3]);
    });

    test('cliente=cli_a só matcha o cliente literal', () async {
      final r = await _get(handler, '/?cliente=cli_a');
      final body = await _decodeList(r);
      final nomes = body.map((p) => p['cliente_nome'] as String).toSet();
      expect(nomes, {'cli_a'});
    });

    test('busca=arq (sem metacaracter) continua matchando ambos', () async {
      final r = await _get(handler, '/?busca=arq');
      final body = await _decodeList(r);
      final lotes = body.map((p) => p['lote'] as int).toSet();
      expect(lotes, {1, 2});
    });
  });
}
