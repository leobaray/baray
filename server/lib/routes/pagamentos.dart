import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../dinheiro.dart';
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
      'SELECT id, pedido_id, valor, forma, quando, observacao '
      'FROM pedido_pagamentos WHERE pedido_id = ? ORDER BY quando DESC',
      [pedidoId],
    );
    return json(rows.map((r) => Pagamento.fromRow(r).toJson()).toList());
  });

  r.post('/pedidos/<pedidoId>', (Request req, String pedidoId) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }
    final valor = (body['valor'] as num?)?.toDouble();
    if (valor == null || !valor.isFinite || valor <= 0) {
      return json({'error': 'valor é obrigatório e deve ser positivo'}, status: 400);
    }

    final pedidoRows = db.raw.select(
      'SELECT valor, valor_pago, fechamento_id FROM pedidos WHERE id = ?',
      [pedidoId],
    );
    if (pedidoRows.isEmpty) {
      return json({'error': 'pedido não encontrado'}, status: 404);
    }
    final pedidoValor = (pedidoRows.first['valor'] as num).toDouble();
    final pedidoPago = ((pedidoRows.first['valor_pago'] as num?) ?? 0).toDouble();
    final fechamentoId = pedidoRows.first['fechamento_id'] as String?;
    final saldo = pedidoValor - pedidoPago;
    if (valor > saldo + kTolerancaCentavos) {
      return json({
        'error': 'valor (R\$ ${valor.toStringAsFixed(2)}) excede o saldo devedor (R\$ ${saldo.toStringAsFixed(2)})',
      }, status: 400);
    }

    final id = uuid.v4();
    final quando = (body['quando'] as String?) ?? DateTime.now().toUtc().toIso8601String();

    db.transaction(() {
      db.raw.execute(
        'INSERT INTO pedido_pagamentos (id, pedido_id, valor, forma, quando, observacao) VALUES (?,?,?,?,?,?)',
        [id, pedidoId, valor, body['forma'], quando, body['observacao']],
      );
      recalcularPagamento(db.raw, pedidoId);
      if (fechamentoId != null) {
        _refletirAgregadoFechamento(db, fechamentoId);
      }
    });

    final created = db.raw.select(
      'SELECT id, pedido_id, valor, forma, quando, observacao '
      'FROM pedido_pagamentos WHERE id = ?',
      [id],
    ).first;
    return json(Pagamento.fromRow(created).toJson(), status: 201);
  });

  r.delete('/<id>', (Request req, String id) {
    final rows = db.raw.select(
      'SELECT pp.pedido_id, p.fechamento_id FROM pedido_pagamentos pp '
      'LEFT JOIN pedidos p ON p.id = pp.pedido_id WHERE pp.id = ?',
      [id],
    );
    if (rows.isEmpty) return json({'error': 'não encontrado'}, status: 404);
    final pedidoId = rows.first['pedido_id'] as String;
    final fechamentoId = rows.first['fechamento_id'] as String?;

    db.transaction(() {
      db.raw.execute('DELETE FROM pedido_pagamentos WHERE id = ?', [id]);
      recalcularPagamento(db.raw, pedidoId);
      if (fechamentoId != null) {
        _refletirAgregadoFechamento(db, fechamentoId);
      }
    });
    return json({'ok': true});
  });

  return r;
}

void _refletirAgregadoFechamento(Db db, String fechamentoId) {
  final agg = db.raw.select(
    'SELECT COUNT(*) AS total, COALESCE(SUM(valor), 0) AS vt, COALESCE(SUM(valor_pago), 0) AS vp '
    'FROM pedidos WHERE fechamento_id = ?',
    [fechamentoId],
  ).first;
  db.raw.execute('''
    UPDATE cliente_fechamentos
    SET total_pedidos = ?, valor_total = ?, valor_pago = ?, atualizado_em = ?
    WHERE id = ?
  ''', [
    agg['total'] as int,
    (agg['vt'] as num).toDouble(),
    (agg['vp'] as num).toDouble(),
    DateTime.now().toUtc().toIso8601String(),
    fechamentoId,
  ]);
}
