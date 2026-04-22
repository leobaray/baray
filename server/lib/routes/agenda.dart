import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db.dart';
import '../models/pedido.dart';

/// Rotas de agenda — calculam ocupação por dia a partir da tabela
/// `pedido_distribuicao` (pedidos grandes se espalham por múltiplos dias),
/// caindo em `pedidos.data_producao` quando não há distribuição.
Router agendaRouter(Db db) {
  final r = Router();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/ocupacao', (Request req) {
    final qp = req.url.queryParameters;
    final deStr = qp['de'];
    final ateStr = qp['ate'];
    if (deStr == null || ateStr == null) {
      return json({'error': 'de e ate são obrigatórios (YYYY-MM-DD)'}, status: 400);
    }
    final de = DateTime.tryParse(deStr);
    final ate = DateTime.tryParse(ateStr);
    if (de == null || ate == null || ate.isBefore(de)) {
      return json({'error': 'datas inválidas'}, status: 400);
    }
    // Guarda contra ranges absurdos.
    final dias = ate.difference(de).inDays;
    if (dias > 90) {
      return json({'error': 'range máximo: 90 dias'}, status: 400);
    }

    final limite = db.configNumber('limite_diario', 1200);

    // Ocupação: somar parcelas da distribuição + pedidos sem distribuição.
    final ocupacao = <String, double>{};

    final distribRows = db.raw.select(
      'SELECT data, parcela_valor FROM pedido_distribuicao '
      'WHERE data >= ? AND data <= ?',
      [deStr, ateStr],
    );
    for (final row in distribRows) {
      final d = row['data'] as String;
      ocupacao[d] = (ocupacao[d] ?? 0) + (row['parcela_valor'] as num).toDouble();
    }

    final pedidosSemDistribRows = db.raw.select(
      'SELECT data_producao, valor FROM pedidos '
      'WHERE data_producao IS NOT NULL '
      'AND data_producao >= ? AND data_producao <= ? '
      'AND NOT EXISTS (SELECT 1 FROM pedido_distribuicao d WHERE d.pedido_id = pedidos.id)',
      [deStr, ateStr],
    );
    for (final row in pedidosSemDistribRows) {
      final dRaw = row['data_producao'] as String;
      final d = dRaw.length >= 10 ? dRaw.substring(0, 10) : dRaw;
      ocupacao[d] = (ocupacao[d] ?? 0) + (row['valor'] as num).toDouble();
    }

    // Todos os pedidos do range pra agrupar por dia de início.
    final pedidosRows = db.raw.select(
      'SELECT * FROM pedidos '
      'WHERE data_producao IS NOT NULL '
      'AND data_producao >= ? AND data_producao <= ? '
      'ORDER BY lote DESC',
      [deStr, ateStr],
    );
    final pedidosPorDia = <String, List<Map<String, dynamic>>>{};
    for (final row in pedidosRows) {
      final dRaw = row['data_producao'] as String;
      final d = dRaw.length >= 10 ? dRaw.substring(0, 10) : dRaw;
      (pedidosPorDia[d] ??= []).add(Pedido.fromRow(row).toJson());
    }

    // Pedidos sem data de produção (pra indicador).
    final semDataRow = db.raw.select(
      "SELECT COUNT(*) AS n FROM pedidos WHERE data_producao IS NULL AND status != 'entregue'",
    ).first;

    // Montar dias do range (inclui dias vazios).
    final diasResp = <Map<String, dynamic>>[];
    var cursor = DateTime(de.year, de.month, de.day);
    final alvo = DateTime(ate.year, ate.month, ate.day);
    while (!cursor.isAfter(alvo)) {
      final chave = _chaveDia(cursor);
      diasResp.add({
        'data': chave,
        'ocupado': ocupacao[chave] ?? 0.0,
        'limite': limite,
        'pedidos': pedidosPorDia[chave] ?? <Map<String, dynamic>>[],
      });
      cursor = cursor.add(const Duration(days: 1));
    }

    return json({
      'dias': diasResp,
      'sem_data': semDataRow['n'] as int,
    });
  });

  return r;
}

String _chaveDia(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
