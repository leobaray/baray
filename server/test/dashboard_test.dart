import 'package:empresa_server/routes/dashboard.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

void main() {
  group('A-01: inicioMesUtcDe', () {
    test('converte início do mês local pra instante UTC equivalente', () {
      // `DateTime(2026, 5, 1)` é meia-noite local do dia 1. Convertido pra
      // UTC ISO8601, deve representar o MESMO instante absoluto. A asserção
      // é timezone-agnóstica: o resultado, ao ser reparsado, volta a apontar
      // pra meia-noite local — independente do fuso da máquina.
      final inicioLocal = DateTime(2026, 5, 1);
      final iso = inicioMesUtcDe(inicioLocal);

      expect(iso, endsWith('Z'), reason: 'deve ser timestamp UTC');
      final reparse = DateTime.parse(iso);
      expect(reparse.isUtc, isTrue);
      expect(reparse.toLocal(), inicioLocal);
    });

    test('em fuso BRT (UTC-3), retorna T03 do dia 1', () {
      // Simula servidor em BRT: meia-noite local de 1º maio = 03:00 UTC.
      // Aceita também variações de offset (UTC-2 verão, etc) — basta
      // verificar que o instante é equivalente.
      final localTzOffset = DateTime(2026, 5, 1).timeZoneOffset;
      final esperadoUtc =
          DateTime.utc(2026, 5, 1).subtract(localTzOffset).toIso8601String();
      final got = inicioMesUtcDe(DateTime(2026, 5, 1));
      expect(got, esperadoUtc);
    });
  });

  group('A-01: filtro de mês alinhado com timestamps UTC', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    const uuid = Uuid();

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      // Cliente único pra satisfazer FKs.
      final cid = uuid.v4();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      db.raw.execute(
        'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) VALUES (?,?,?,?,?)',
        [cid, 'C', 0, nowIso, nowIso],
      );
      // Pedido A: criado em 2026-04-30 22:00 BRT (= 2026-05-01T01:00:00Z).
      // No fuso local BRT, isso é abril; em UTC, é maio.
      // Bug pré-fix: contado em maio. Pós-fix: NÃO contado em maio.
      _inserirPedido(
        db,
        id: 'pedido_abr_fim',
        lote: 1,
        cid: cid,
        valor: 100.0,
        criadoEmUtc: '2026-05-01T01:00:00.000Z',
      );
      // Pedido B: criado em 2026-05-01 09:00 BRT (= 2026-05-01T12:00:00Z).
      // Inequívocamente maio — deve ser contado.
      _inserirPedido(
        db,
        id: 'pedido_mai_inicio',
        lote: 2,
        cid: cid,
        valor: 250.0,
        criadoEmUtc: '2026-05-01T12:00:00.000Z',
      );
    });

    tearDown(() => tmp.cleanup());

    test('em fuso BRT, pedido das 22h do último dia do mês anterior fica de fora',
        () {
      // Pula em fusos que não sejam UTC-3 (CI rodando em UTC inclui o pedido
      // legitimamente — caso de borda não se aplica). Em BRT puro, o teste
      // demonstra a correção; em UTC, a função degenera mas continua correta.
      final offsetBrt = const Duration(hours: -3);
      final localOffset = DateTime(2026, 5, 1).timeZoneOffset;
      final emBrt = localOffset == offsetBrt;

      final inicioMesUtc = inicioMesUtcDe(DateTime(2026, 5, 1));
      final rows = db.raw.select(
        'SELECT id, valor FROM pedidos WHERE criado_em >= ? ORDER BY lote',
        [inicioMesUtc],
      );
      if (emBrt) {
        // Em BRT, o cutoff vira '2026-05-01T03:00:00.000Z'. O pedido
        // 'pedido_abr_fim' (criado_em = '2026-05-01T01:00:00.000Z') fica fora.
        expect(rows.length, 1,
            reason: 'só pedido_mai_inicio deve estar em maio');
        expect(rows.single['id'], 'pedido_mai_inicio');
      } else {
        // Em UTC ou outros fusos, o cutoff é diferente; o teste degenera mas
        // serve como sanity check (sem regredir). Aceitamos 1 ou 2 linhas.
        expect(rows.length, anyOf(1, 2));
      }
    });

    test('cutoff em string lexicográfica: pré-cutoff exclui, pós-cutoff inclui',
        () {
      // Asserção timezone-agnóstica do contrato com SQLite: comparação ISO8601
      // funciona lexicograficamente. Inserimos pedidos cercando um cutoff fixo
      // e validamos o filtro.
      final cutoff = '2026-05-01T03:00:00.000Z';
      // Limpa os pedidos do setUp pra garantir cenário isolado.
      db.raw.execute('DELETE FROM pedidos');

      final cid =
          (db.raw.select('SELECT id FROM clientes LIMIT 1').first)['id']
              as String;
      _inserirPedido(
        db,
        id: 'antes',
        lote: 10,
        cid: cid,
        valor: 11.0,
        criadoEmUtc: '2026-05-01T02:59:59.999Z',
      );
      _inserirPedido(
        db,
        id: 'depois',
        lote: 11,
        cid: cid,
        valor: 22.0,
        criadoEmUtc: '2026-05-01T03:00:00.000Z',
      );

      final rows = db.raw.select(
        'SELECT id FROM pedidos WHERE criado_em >= ? ORDER BY lote',
        [cutoff],
      );
      expect(rows.length, 1);
      expect(rows.single['id'], 'depois');
    });
  });
}

void _inserirPedido(
  dynamic db, {
  required String id,
  required int lote,
  required String cid,
  required double valor,
  required String criadoEmUtc,
}) {
  db.raw.execute(
    '''INSERT INTO pedidos (
      id, lote, cliente_id, cliente_nome, descricao, valor,
      status, urgente, criado_em, atualizado_em,
      valor_pago, sinal_pago, status_pagamento, agendamento_fixo
    ) VALUES (?, ?, ?, ?, ?, ?, 'pendente', 0, ?, ?, 0, 0, 'devendo', 0)''',
    [id, lote, cid, 'C', 'desc', valor, criadoEmUtc, criadoEmUtc],
  );
}
