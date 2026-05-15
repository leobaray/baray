import 'package:sqlite3/sqlite3.dart';

/// Recalcula `valor_pago` (cache derivado de `pedido_pagamentos`) e ajusta
/// `status_pagamento`. Aceita uma tolerância de R\$ 0,01 para arredondamentos.
void recalcularPagamento(Database raw, String pedidoId) {
  final pedidoRows = raw.select('SELECT valor FROM pedidos WHERE id=?', [pedidoId]);
  if (pedidoRows.isEmpty) return;
  final valorTotal = (pedidoRows.first['valor'] as num).toDouble();

  final somaRow = raw.select(
    'SELECT COALESCE(SUM(valor), 0) AS s FROM pedido_pagamentos WHERE pedido_id=?',
    [pedidoId],
  ).first;
  final pago = (somaRow['s'] as num).toDouble();

  final String status;
  if (pago >= valorTotal - 0.01) {
    status = 'pago';
  } else if (pago > 0.01) {
    status = 'parcial';
  } else {
    status = 'devendo';
  }

  raw.execute(
    'UPDATE pedidos SET valor_pago=?, status_pagamento=?, atualizado_em=? WHERE id=?',
    [pago, status, DateTime.now().toUtc().toIso8601String(), pedidoId],
  );
}
