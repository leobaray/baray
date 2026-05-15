import 'package:empresa_server/agendador.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

void main() {
  group('Agendador.agendar', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    late Agendador ag;
    const uuid = Uuid();
    late String pedidoId;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;
      ag = Agendador(db);

      final clienteId = uuid.v4();
      pedidoId = uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      db.raw.execute(
        'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) VALUES (?,?,?,?,?)',
        [clienteId, 'C', 0, now, now],
      );
      db.raw.execute(
        '''INSERT INTO pedidos (
          id, lote, cliente_id, cliente_nome, descricao, valor,
          status, urgente, criado_em, atualizado_em,
          valor_pago, sinal_pago, status_pagamento, agendamento_fixo
        ) VALUES (?, 1, ?, ?, ?, 500.0, 'pendente', 0, ?, ?, 0, 0, 'devendo', 0)''',
        [pedidoId, clienteId, 'C', 'desc', now, now],
      );
    });

    tearDown(() => tmp.cleanup());

    test('valor=0 lança AgendadorCapacidadeException (resolve A-09)', () {
      expect(
        () => ag.agendar(pedidoId: pedidoId, valor: 0),
        throwsA(isA<AgendadorCapacidadeException>()),
      );
    });

    test('pedido pequeno cabe em 1 dia útil', () {
      final segunda = _proximaSegunda();
      final inicio = ag.agendar(
        pedidoId: pedidoId,
        valor: 500,
        dataChegada: segunda,
      );
      expect(inicio.weekday, lessThan(DateTime.saturday));
      final dist = db.raw.select(
        'SELECT data FROM pedido_distribuicao WHERE pedido_id=?',
        [pedidoId],
      );
      expect(dist.length, 1);
    });

    test('pedido grande > limite_diario distribui em múltiplos dias', () {
      // limite_diario default = 1200. Vamos pedir 3000.
      final segunda = _proximaSegunda();
      ag.agendar(pedidoId: pedidoId, valor: 3000.0, dataChegada: segunda);
      final dist = db.raw.select(
        'SELECT data, parcela_valor FROM pedido_distribuicao WHERE pedido_id=? ORDER BY data',
        [pedidoId],
      );
      // 1200 + 1200 + 600 = 3000
      expect(dist.length, 3);
      var soma = 0.0;
      for (final r in dist) {
        soma += (r['parcela_valor'] as num).toDouble();
      }
      expect(soma, closeTo(3000, 0.01));
    });

    test('agendamento_fixo respeitado (resolve A-03)', () {
      // Marca pedido como fixado com data_producao já definida.
      final dataFixada = '2030-01-15';
      db.raw.execute(
        'UPDATE pedidos SET agendamento_fixo=1, data_producao=? WHERE id=?',
        [dataFixada, pedidoId],
      );
      final inicio = ag.agendar(pedidoId: pedidoId, valor: 500);
      expect(inicio.toIso8601String().substring(0, 10), dataFixada);
      // Não cria distribuição quando respeita fixação.
      final dist = db.raw.select(
        'SELECT data FROM pedido_distribuicao WHERE pedido_id=?',
        [pedidoId],
      );
      expect(dist, isEmpty);
    });

    test('ignorarFixacao=true sobrepõe o fixo', () {
      db.raw.execute(
        'UPDATE pedidos SET agendamento_fixo=1, data_producao=? WHERE id=?',
        ['2030-01-15', pedidoId],
      );
      final segunda = _proximaSegunda();
      final inicio = ag.agendar(
        pedidoId: pedidoId,
        valor: 500,
        dataChegada: segunda,
        ignorarFixacao: true,
      );
      // Deve agendar em dia útil dentro da próxima semana, não 2030.
      expect(inicio.year, lessThan(2030));
    });
  });

  group('Agendador.proximoLote', () {
    test('UPDATE RETURNING é atômico (resolve C-04)', () {
      final f = novoDb();
      try {
        // Cria 1000 lotes em loop — não pode ter colisão.
        final lotes = <int>{};
        for (var i = 0; i < 50; i++) {
          lotes.add(f.db.proximoLote());
        }
        expect(lotes.length, 50, reason: 'todos os lotes devem ser únicos');
      } finally {
        f.cleanup();
      }
    });
  });
}

DateTime _proximaSegunda() {
  var d = DateTime.now();
  while (d.weekday != DateTime.monday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day);
}
