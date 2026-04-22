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
    final fimMes = DateTime(hoje.year, hoje.month + 1, 0);
    final fimMesStr = _dataStr(fimMes);

    // Vendas do mês — total de pedidos criados (volume de negócio).
    final vendasRow = db.raw.select(
      'SELECT COALESCE(SUM(valor), 0) AS s, COUNT(*) AS n FROM pedidos WHERE criado_em >= ?',
      [inicioMesStr],
    ).first;
    final vendasMes = (vendasRow['s'] as num).toDouble();
    final pedidosMes = vendasRow['n'] as int;

    // Recebido no mês — pagamentos efetivos registrados.
    final recebidoRow = db.raw.select(
      'SELECT COALESCE(SUM(valor), 0) AS s FROM pedido_pagamentos WHERE quando >= ?',
      [inicioMesStr],
    ).first;
    final recebidoMes = (recebidoRow['s'] as num).toDouble();

    // Pedidos concluídos no mês (entregues com base em entregue_em).
    final concluidosRow = db.raw.select(
      'SELECT COUNT(*) AS n FROM pedidos WHERE entregue_em >= ?',
      [inicioMesStr],
    ).first;
    final concluidosMes = concluidosRow['n'] as int;

    // Ticket médio do mês.
    final ticketMedio = pedidosMes > 0 ? vendasMes / pedidosMes : 0.0;

    // A receber (saldo devedor agregado).
    final aReceberRow = db.raw.select(
      'SELECT COALESCE(SUM(valor - valor_pago), 0) AS s FROM pedidos '
      "WHERE status_pagamento != 'pago' AND status != 'entregue'",
    ).first;

    // Em produção hoje.
    final emProducaoRows = db.raw.select(
      'SELECT * FROM pedidos WHERE data_producao = ? ORDER BY lote',
      [hojeStr],
    );
    final emProducao = emProducaoRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // Urgentes abertos (urgente=1 e não entregue).
    final urgentesRows = db.raw.select(
      "SELECT * FROM pedidos WHERE urgente = 1 AND status != 'entregue' ORDER BY lote DESC",
    );
    final urgentes = urgentesRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // Prazos em atenção: pedido não entregue com data_entrega até 7 dias à frente.
    final em7dias = hoje.add(const Duration(days: 7));
    final vencendoRows = db.raw.select(
      'SELECT * FROM pedidos WHERE data_entrega_combinada IS NOT NULL '
      "AND data_entrega_combinada <= ? AND status != 'entregue' "
      'ORDER BY data_entrega_combinada ASC',
      [_dataStr(em7dias)],
    );
    final vencendo = vencendoRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // Ocupação dos próximos 7 dias úteis.
    final ocupacao = agendador.proximosDias(7);

    return json({
      'vendas_mes': vendasMes,
      'recebido_mes': recebidoMes,
      'pedidos_mes': pedidosMes,
      'concluidos_mes': concluidosMes,
      'ticket_medio': ticketMedio,
      'a_receber': (aReceberRow['s'] as num).toDouble(),
      'em_producao_hoje': emProducao,
      'urgentes': urgentes,
      'prazos_vencendo': vencendo,
      'ocupacao_semana': ocupacao,
      'hoje': hojeStr,
      'inicio_mes': inicioMesStr,
      'fim_mes': fimMesStr,
    });
  });

  return r;
}

String _dataStr(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
