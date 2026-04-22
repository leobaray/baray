import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/pagamento.dart';
import '../pagamentos_util.dart';

Router pagamentosRouter(Db db) {
  final r = Router();
  const uuid = Uuid();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/pedidos/<pedidoId>', (Request req, String pedidoId) {
    final rows = db.raw.select(
      'SELECT * FROM pedido_pagamentos WHERE pedido_id = ? ORDER BY quando DESC',
      [pedidoId],
    );
    return json(rows.map((r) => Pagamento.fromRow(r).toJson()).toList());
  });

  r.post('/pedidos/<pedidoId>', (Request req, String pedidoId) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final valor = (body['valor'] as num?)?.toDouble();
    if (valor == null || valor <= 0) {
      return json({'error': 'valor é obrigatório e deve ser positivo'}, status: 400);
    }

    // Validar que o pagamento não excede o saldo devedor.
    final pedidoRows = db.raw.select(
      'SELECT valor, valor_pago FROM pedidos WHERE id = ?',
      [pedidoId],
    );
    if (pedidoRows.isEmpty) {
      return json({'error': 'pedido não encontrado'}, status: 404);
    }
    final pedidoValor = (pedidoRows.first['valor'] as num).toDouble();
    final pedidoPago = ((pedidoRows.first['valor_pago'] as num?) ?? 0).toDouble();
    final saldo = pedidoValor - pedidoPago;
    if (valor > saldo + 0.01) {
      return json({
        'error': 'valor (R\$ ${valor.toStringAsFixed(2)}) excede o saldo devedor (R\$ ${saldo.toStringAsFixed(2)})',
      }, status: 400);
    }

    final id = uuid.v4();
    final quando = (body['quando'] as String?) ?? DateTime.now().toIso8601String();
    db.raw.execute(
      'INSERT INTO pedido_pagamentos (id, pedido_id, valor, forma, quando, observacao) VALUES (?,?,?,?,?,?)',
      [id, pedidoId, valor, body['forma'], quando, body['observacao']],
    );

    recalcularPagamento(db.raw, pedidoId);

    final created = db.raw.select('SELECT * FROM pedido_pagamentos WHERE id = ?', [id]).first;
    return json(Pagamento.fromRow(created).toJson(), status: 201);
  });

  r.delete('/<id>', (Request req, String id) {
    final rows = db.raw.select('SELECT pedido_id FROM pedido_pagamentos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'não encontrado'}, status: 404);
    final pedidoId = rows.first['pedido_id'] as String;
    db.raw.execute('DELETE FROM pedido_pagamentos WHERE id = ?', [id]);
    recalcularPagamento(db.raw, pedidoId);
    return json({'ok': true});
  });

  return r;
}
