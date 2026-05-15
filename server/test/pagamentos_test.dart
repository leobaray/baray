import 'package:empresa_server/pagamentos_util.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'fixtures.dart';

void main() {
  group('recalcularPagamento', () {
    late ({void Function() cleanup}) tmp;
    late dynamic db;
    const uuid = Uuid();
    late String pedidoId;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      db = f.db;

      // Cria cliente + pedido com valor 100.
      final clienteId = uuid.v4();
      pedidoId = uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      db.raw.execute(
        'INSERT INTO clientes (id, nome, fechamento_ativo, criado_em, atualizado_em) VALUES (?,?,?,?,?)',
        [clienteId, 'Cliente Teste', 0, now, now],
      );
      db.raw.execute(
        '''INSERT INTO pedidos (
          id, lote, cliente_id, cliente_nome, descricao, valor,
          status, urgente, criado_em, atualizado_em,
          valor_pago, sinal_pago, status_pagamento, agendamento_fixo
        ) VALUES (?, 1, ?, ?, ?, 100.0, 'pendente', 0, ?, ?, 0, 0, 'devendo', 0)''',
        [pedidoId, clienteId, 'Cliente Teste', 'desc', now, now],
      );
    });

    tearDown(() => tmp.cleanup());

    test('sem pagamentos → status devendo, valor_pago=0', () {
      recalcularPagamento(db.raw, pedidoId);
      final r = db.raw.select(
        'SELECT valor_pago, status_pagamento FROM pedidos WHERE id=?',
        [pedidoId],
      ).first;
      expect(r['valor_pago'], 0);
      expect(r['status_pagamento'], 'devendo');
    });

    test('pagamento parcial → status parcial', () {
      _inserirPagamento(db, pedidoId, 30);
      recalcularPagamento(db.raw, pedidoId);
      final r = db.raw.select(
        'SELECT valor_pago, status_pagamento FROM pedidos WHERE id=?',
        [pedidoId],
      ).first;
      expect(r['valor_pago'], 30);
      expect(r['status_pagamento'], 'parcial');
    });

    test('pagamento total → status pago', () {
      _inserirPagamento(db, pedidoId, 100);
      recalcularPagamento(db.raw, pedidoId);
      final r = db.raw.select(
        'SELECT valor_pago, status_pagamento FROM pedidos WHERE id=?',
        [pedidoId],
      ).first;
      expect(r['valor_pago'], 100);
      expect(r['status_pagamento'], 'pago');
    });

    test('tolerância de R\$ 0,01 para arredondamento', () {
      _inserirPagamento(db, pedidoId, 99.995);
      recalcularPagamento(db.raw, pedidoId);
      final r = db.raw.select(
        'SELECT status_pagamento FROM pedidos WHERE id=?',
        [pedidoId],
      ).first;
      expect(r['status_pagamento'], 'pago');
    });

    test('múltiplos pagamentos somam corretamente', () {
      _inserirPagamento(db, pedidoId, 40);
      _inserirPagamento(db, pedidoId, 35);
      _inserirPagamento(db, pedidoId, 25);
      recalcularPagamento(db.raw, pedidoId);
      final r = db.raw.select(
        'SELECT valor_pago, status_pagamento FROM pedidos WHERE id=?',
        [pedidoId],
      ).first;
      expect(r['valor_pago'], 100);
      expect(r['status_pagamento'], 'pago');
    });
  });
}

void _inserirPagamento(dynamic db, String pedidoId, double valor) {
  db.raw.execute(
    'INSERT INTO pedido_pagamentos (id, pedido_id, valor, forma, quando) VALUES (?,?,?,?,?)',
    [
      const Uuid().v4(),
      pedidoId,
      valor,
      'pix',
      DateTime.now().toUtc().toIso8601String(),
    ],
  );
}
