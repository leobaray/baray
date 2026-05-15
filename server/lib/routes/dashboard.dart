import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../agendador.dart';
import '../db.dart';
import '../models/pedido.dart';

const String _pedidoCols =
    'id, lote, cliente_id, cliente_nome, cliente_telefone, cliente_email, '
    'descricao, peca, tecnica, quantidade, valor, '
    'cor_peca, tamanho_peca, tecido, '
    'arte_cores, arte_tamanho_cm, arte_posicao, arte_observacao, '
    'data_chegada, data_producao, prazo_dias, agendamento_fixo, '
    'forma_entrega, endereco_entrega, data_entrega_combinada, entregue_em, entregue_por, '
    'forma_pagamento, valor_pago, sinal_pago, status_pagamento, '
    'status, urgente, observacao, regiao, tipo_peca, fechamento_id, criado_em, atualizado_em';

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

    final vendasRow = db.raw.select(
      'SELECT COALESCE(SUM(valor), 0) AS s, COUNT(*) AS n FROM pedidos WHERE criado_em >= ?',
      [inicioMesStr],
    ).first;
    final vendasMes = (vendasRow['s'] as num).toDouble();
    final pedidosMes = vendasRow['n'] as int;

    final recebidoRow = db.raw.select(
      'SELECT COALESCE(SUM(valor), 0) AS s FROM pedido_pagamentos WHERE quando >= ?',
      [inicioMesStr],
    ).first;
    final recebidoMes = (recebidoRow['s'] as num).toDouble();

    final concluidosRow = db.raw.select(
      'SELECT COUNT(*) AS n FROM pedidos WHERE entregue_em >= ?',
      [inicioMesStr],
    ).first;
    final concluidosMes = concluidosRow['n'] as int;

    final ticketMedio = pedidosMes > 0 ? vendasMes / pedidosMes : 0.0;

    final aReceberRow = db.raw.select(
      'SELECT COALESCE(SUM(valor - valor_pago), 0) AS s FROM pedidos '
      "WHERE status_pagamento != 'pago' AND status != 'entregue'",
    ).first;

    final emProducaoRows = db.raw.select(
      'SELECT $_pedidoCols FROM pedidos WHERE data_producao = ? ORDER BY lote',
      [hojeStr],
    );
    final emProducao = emProducaoRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    final urgentesRows = db.raw.select(
      "SELECT $_pedidoCols FROM pedidos WHERE urgente = 1 AND status != 'entregue' ORDER BY lote DESC",
    );
    final urgentes = urgentesRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    // A-11: separar atrasados (data < hoje) de vencendo (hoje..hoje+7).
    // Floor evita "vencendo" mostrar coisa de 2020.
    final em7dias = hoje.add(const Duration(days: 7));
    final atrasadosRows = db.raw.select(
      'SELECT $_pedidoCols FROM pedidos WHERE data_entrega_combinada IS NOT NULL '
      "AND data_entrega_combinada < ? AND status != 'entregue' "
      'ORDER BY data_entrega_combinada ASC',
      [hojeStr],
    );
    final atrasados = atrasadosRows.map((r) => Pedido.fromRow(r).toJson()).toList();

    final vencendoRows = db.raw.select(
      'SELECT $_pedidoCols FROM pedidos WHERE data_entrega_combinada IS NOT NULL '
      "AND data_entrega_combinada >= ? AND data_entrega_combinada <= ? AND status != 'entregue' "
      'ORDER BY data_entrega_combinada ASC',
      [hojeStr, _dataStr(em7dias)],
    );
    final vencendo = vencendoRows.map((r) => Pedido.fromRow(r).toJson()).toList();

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
      'atrasados': atrasados,
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
