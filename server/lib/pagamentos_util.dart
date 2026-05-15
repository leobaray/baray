import 'package:sqlite3/sqlite3.dart';

import 'dinheiro.dart';

/// Recalcula `valor_pago` (cache derivado de `pedido_pagamentos`) e ajusta
/// `status_pagamento`. Aceita uma tolerância de [kTolerancaCentavos] para
/// arredondamentos (ver AUDIT A-04 e `dinheiro.dart`).
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
  if (pago >= valorTotal - kTolerancaCentavos) {
    status = 'pago';
  } else if (ehMaiorQueZero(pago)) {
    status = 'parcial';
  } else {
    status = 'devendo';
  }

  raw.execute(
    'UPDATE pedidos SET valor_pago=?, status_pagamento=?, atualizado_em=? WHERE id=?',
    [pago, status, DateTime.now().toUtc().toIso8601String(), pedidoId],
  );
}
