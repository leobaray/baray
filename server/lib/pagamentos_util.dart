import 'package:sqlite3/sqlite3.dart';

/// Recalcula e ajusta o status_pagamento do pedido com base nos pagamentos.
void recalcularPagamento(Database raw, String pedidoId) {
  final pedidoRows = raw.select('SELECT valor FROM pedidos WHERE id=?', [pedidoId]);
  if (pedidoRows.isEmpty) return;
  final valorTotal = (pedidoRows.first['valor'] as num).toDouble();

  final somaRow = raw.select(
    'SELECT COALESCE(SUM(valor), 0) AS s FROM pedido_pagamentos WHERE pedido_id=?',
    [pedidoId],
  ).first;
  final pago = (somaRow['s'] as num).toDouble();

  String status;
  if (pago >= valorTotal - 0.01) {
    status = 'pago';
  } else if (pago > 0.01) {
    status = 'parcial';
  } else {
    status = 'devendo';
  }

  raw.execute(
    'UPDATE pedidos SET valor_pago=?, status_pagamento=?, atualizado_em=? WHERE id=?',
    [pago, status, DateTime.now().toIso8601String(), pedidoId],
  );
}
