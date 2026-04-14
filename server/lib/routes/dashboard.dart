import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db.dart';
import '../models/pedido.dart';
import '../agendador.dart';

Router dashboardRouter(Db db) {
  final r = Router();
  final agendador = Agendador(db);

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/stats', (Request req) {
    final hoje = DateTime.now();
    final hojeStr = _dataStr(hoje);
    final inicioMes = DateTime(hoje.year, hoje.month, 1);
    final inicioMesStr = _dataStr(inicioMes);

    // Faturamento do mês (baseado em criado_em)
    final faturamentoRow = db.raw.select(
      'SELECT COALESCE(SUM(valor), 0) AS s FROM pedidos WHERE criado_em >= ?',
      [inicioMesStr],
    ).first;

    // A receber
    final aReceberRow = db.raw.select(
      'SELECT COALESCE(SUM(valor - valor_pago), 0) AS s FROM pedidos '
      "WHERE status_pagamento != 'pago' AND status != 'entregue'",
    ).first;

    // Em produção hoje
    final emProducaoRows = db.raw.select(
      'SELECT * FROM pedidos WHERE data_producao = ? ORDER BY lote',
      [hojeStr],
    );
    final emProducao = emProducaoRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // Prazos vencendo em 7 dias
    final em7dias = hoje.add(const Duration(days: 7));
    final vencendoRows = db.raw.select(
      'SELECT * FROM pedidos WHERE data_entrega_combinada IS NOT NULL '
      "AND data_entrega_combinada <= ? AND status != 'entregue' "
      'ORDER BY data_entrega_combinada ASC',
      [_dataStr(em7dias)],
    );
    final vencendo = vencendoRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // Últimos movimentos
    final ultimosRows = db.raw.select(
      'SELECT * FROM pedidos ORDER BY atualizado_em DESC LIMIT 5',
    );
    final ultimos = ultimosRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // Ocupação dos próximos 7 dias úteis
    final ocupacao = agendador.proximosDias(7);

    // Contagens por status
    final statusRows = db.raw.select(
      'SELECT status, COUNT(*) AS n FROM pedidos GROUP BY status',
    );
    final porStatus = <String, int>{};
    for (final s in statusRows) {
      porStatus[s['status'] as String] = s['n'] as int;
    }

    return json({
      'faturamento_mes': (faturamentoRow['s'] as num).toDouble(),
      'a_receber': (aReceberRow['s'] as num).toDouble(),
      'em_producao_hoje': emProducao,
      'prazos_vencendo': vencendo,
      'ultimos_movimentos': ultimos,
      'ocupacao_semana': ocupacao,
      'por_status': porStatus,
    });
  });

  return r;
}

String _dataStr(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
