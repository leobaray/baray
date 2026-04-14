import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/pedido.dart';
import '../agendador.dart';

Router pedidosRouter(Db db) {
  final r = Router();
  const uuid = Uuid();
  final agendador = Agendador(db);

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  // ── Lista ──────────────────────────────────────────────────────────────
  r.get('/', (Request req) {
    final qp = req.url.queryParameters;
    final where = <String>[];
    final args = <Object?>[];

    void eq(String campo, String? valor) {
      if (valor == null || valor.isEmpty) return;
      where.add('$campo = ?');
      args.add(valor);
    }

    eq('status', qp['status']);
    eq('status_pagamento', qp['status_pagamento']);
    eq('tecnica', qp['tecnica']);

    if ((qp['cliente'] ?? '').isNotEmpty) {
      where.add('cliente_nome LIKE ?');
      args.add('%${qp['cliente']}%');
    }
    if ((qp['cliente_id'] ?? '').isNotEmpty) {
      where.add('cliente_id = ?');
      args.add(qp['cliente_id']);
    }
    if ((qp['busca'] ?? '').isNotEmpty) {
      where.add('(descricao LIKE ? OR observacao LIKE ? OR cliente_nome LIKE ? OR CAST(lote AS TEXT) LIKE ?)');
      final termo = '%${qp['busca']}%';
      args.addAll([termo, termo, termo, termo]);
    }
    if (qp['urgente'] == 'true') where.add('urgente = 1');
    if (qp['de'] != null && qp['de']!.isNotEmpty) {
      where.add('data_producao >= ?');
      args.add(qp['de']);
    }
    if (qp['ate'] != null && qp['ate']!.isNotEmpty) {
      where.add('data_producao <= ?');
      args.add(qp['ate']);
    }

    final sql = StringBuffer('SELECT * FROM pedidos');
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');

    final ordem = switch (qp['ordenar']) {
      'valor' => 'valor DESC',
      'valor_asc' => 'valor ASC',
      'data_producao' => 'data_producao ASC NULLS LAST',
      'prazo' => 'data_entrega_combinada ASC NULLS LAST',
      'criado' => 'criado_em DESC',
      _ => 'lote DESC',
    };
    sql.write(' ORDER BY $ordem');

    final rows = db.raw.select(sql.toString(), args);
    return json(rows.map((row) => Pedido.fromRow(row).toJson()).toList());
  });

  // ── Detalhe ────────────────────────────────────────────────────────────
  r.get('/<id>', (Request req, String id) {
    final rows = db.raw.select('SELECT * FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    return json(Pedido.fromRow(rows.first).toJson());
  });

  // ── Criar ──────────────────────────────────────────────────────────────
  r.post('/', (Request req) async {
    final raw = await req.readAsString();
    print('[POST /pedidos] body=$raw');
    final body = jsonDecode(raw) as Map<String, dynamic>;
    final clienteNome = (body['cliente_nome'] as String?)?.trim();
    final descricao = (body['descricao'] as String?)?.trim();
    final valor = (body['valor'] as num?)?.toDouble();
    if (clienteNome == null || clienteNome.isEmpty) {
      print('[POST /pedidos] 400: cliente_nome vazio');
      return json({'error': 'cliente_nome é obrigatório'}, status: 400);
    }
    if (descricao == null || descricao.isEmpty) {
      print('[POST /pedidos] 400: descricao vazia');
      return json({'error': 'descricao é obrigatória'}, status: 400);
    }
    if (valor == null) {
      print('[POST /pedidos] 400: valor nulo');
      return json({'error': 'valor é obrigatório'}, status: 400);
    }

    // Se veio cliente_id mas não nome, buscar nome
    String? clienteId = body['cliente_id'] as String?;

    // Se veio cliente_nome mas não id, tentar casar com clientes existentes
    if (clienteId == null && clienteNome.isNotEmpty) {
      final m = db.raw.select(
        'SELECT id FROM clientes WHERE lower(nome) = lower(?)',
        [clienteNome],
      );
      if (m.isNotEmpty) clienteId = m.first['id'] as String;
    }

    final id = uuid.v4();
    final lote = db.proximoLote();
    final now = DateTime.now().toIso8601String();

    final urgente = (body['urgente'] == true) ? 1 : 0;

    // Verificar se cliente tem ciclo de fechamento aberto
    String? fechamentoId;
    if (clienteId != null) {
      final fechRows = db.raw.select(
        "SELECT id FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
        [clienteId],
      );
      if (fechRows.isNotEmpty) {
        fechamentoId = fechRows.first['id'] as String;
      }
    }

    db.raw.execute('''
      INSERT INTO pedidos (
        id, lote, cliente_id, cliente_nome, cliente_telefone, cliente_email,
        descricao, peca, tecnica, quantidade, valor,
        cor_peca, tamanho_peca, tecido,
        arte_cores, arte_tamanho_cm, arte_posicao, arte_observacao,
        data_chegada, data_producao, prazo_dias, agendamento_fixo,
        forma_entrega, endereco_entrega, data_entrega_combinada, entregue_em, entregue_por,
        forma_pagamento, valor_pago, sinal_pago, status_pagamento,
        status, urgente, observacao, fechamento_id, criado_em, atualizado_em
      ) VALUES (?,?,?,?,?,?, ?,?,?,?,?, ?,?,?, ?,?,?,?, ?,?,?,?, ?,?,?,?,?, ?,?,?,?, ?,?,?,?,?,?,?)
    ''', [
      id,
      lote,
      clienteId,
      clienteNome,
      body['cliente_telefone'],
      body['cliente_email'],
      descricao,
      body['peca'],
      body['tecnica'],
      body['quantidade'],
      valor,
      body['cor_peca'],
      body['tamanho_peca'],
      body['tecido'],
      body['arte_cores'],
      body['arte_tamanho_cm'],
      body['arte_posicao'],
      body['arte_observacao'],
      body['data_chegada'],
      body['data_producao'],
      body['prazo_dias'],
      (body['agendamento_fixo'] == true) ? 1 : 0,
      body['forma_entrega'],
      body['endereco_entrega'],
      body['data_entrega_combinada'],
      body['entregue_em'],
      body['entregue_por'],
      body['forma_pagamento'],
      (body['valor_pago'] as num?)?.toDouble() ?? 0,
      (body['sinal_pago'] as num?)?.toDouble() ?? 0,
      body['status_pagamento'] ?? 'devendo',
      body['status'] ?? 'pendente',
      urgente,
      body['observacao'],
      fechamentoId,
      now,
      now,
    ]);

    // Atualizar agregados do fechamento se pedido foi associado
    if (fechamentoId != null) {
      final agg = db.raw.select(
        'SELECT COUNT(*) as total, COALESCE(SUM(valor), 0) as vt, COALESCE(SUM(valor_pago), 0) as vp '
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
        now,
        fechamentoId,
      ]);
    }

    // Se auto_agendar foi pedido ou data_producao não foi passada
    if (body['auto_agendar'] == true || body['data_producao'] == null) {
      try {
        final dataChegada = body['data_chegada'] is String
            ? DateTime.tryParse(body['data_chegada'] as String)
            : null;
        final inicio = agendador.agendar(
          pedidoId: id,
          valor: valor,
          dataChegada: dataChegada,
        );
        final prazoDias = dataChegada != null
            ? agendador.calcularPrazoDias(dataChegada, inicio)
            : null;
        db.raw.execute(
          'UPDATE pedidos SET data_producao=?, prazo_dias=?, status=CASE WHEN status=? THEN ? ELSE status END WHERE id=?',
          [
            _formatarData(inicio),
            prazoDias,
            'pendente',
            'agendado',
            id,
          ],
        );
      } catch (e) {
        // não bloqueia — pedido fica sem data_producao
        print('[agendar] $e');
      }
    }

    final created = db.raw.select('SELECT * FROM pedidos WHERE id = ?', [id]).first;
    return json(Pedido.fromRow(created).toJson(), status: 201);
  });

  // ── Atualizar ──────────────────────────────────────────────────────────
  r.put('/<id>', (Request req, String id) async {
    final exists = db.raw.select('SELECT id FROM pedidos WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);

    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    const editaveis = {
      'cliente_id', 'cliente_nome', 'cliente_telefone', 'cliente_email',
      'descricao', 'peca', 'tecnica', 'quantidade', 'valor',
      'cor_peca', 'tamanho_peca', 'tecido',
      'arte_cores', 'arte_tamanho_cm', 'arte_posicao', 'arte_observacao',
      'data_chegada', 'data_producao', 'prazo_dias', 'agendamento_fixo',
      'forma_entrega', 'endereco_entrega', 'data_entrega_combinada', 'entregue_em', 'entregue_por',
      'forma_pagamento', 'valor_pago', 'sinal_pago', 'status_pagamento',
      'status', 'urgente', 'observacao', 'fechamento_id',
    };

    final sets = <String>[];
    final args = <Object?>[];
    for (final campo in editaveis) {
      if (!body.containsKey(campo)) continue;
      var valor = body[campo];
      if (campo == 'urgente' || campo == 'agendamento_fixo') valor = (valor == true) ? 1 : 0;
      if ((campo == 'valor' || campo == 'valor_pago' || campo == 'sinal_pago') && valor is num) {
        valor = valor.toDouble();
      }
      sets.add('$campo = ?');
      args.add(valor);
    }

    if (sets.isNotEmpty) {
      sets.add('atualizado_em = ?');
      args.add(DateTime.now().toIso8601String());
      args.add(id);
      db.raw.execute('UPDATE pedidos SET ${sets.join(', ')} WHERE id = ?', args);
    }

    final updated = db.raw.select('SELECT * FROM pedidos WHERE id = ?', [id]).first;
    return json(Pedido.fromRow(updated).toJson());
  });

  // ── Deletar ────────────────────────────────────────────────────────────
  r.delete('/<id>', (Request req, String id) {
    final exists = db.raw.select('SELECT id FROM pedidos WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    db.raw.execute('DELETE FROM pedidos WHERE id = ?', [id]);
    return json({'ok': true});
  });

  // ── Agendar automaticamente ───────────────────────────────────────────
  r.post('/<id>/agendar', (Request req, String id) async {
    final rows = db.raw.select('SELECT * FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    final p = Pedido.fromRow(rows.first);
    try {
      final dc = p.dataChegada != null ? DateTime.tryParse(p.dataChegada!) : null;
      final inicio = agendador.agendar(
        pedidoId: id,
        valor: p.valor,
        dataChegada: dc,
      );
      final prazo = dc != null ? agendador.calcularPrazoDias(dc, inicio) : null;
      db.raw.execute(
        'UPDATE pedidos SET data_producao=?, prazo_dias=?, status=CASE WHEN status=? THEN ? ELSE status END, atualizado_em=? WHERE id=?',
        [
          _formatarData(inicio),
          prazo,
          'pendente',
          'agendado',
          DateTime.now().toIso8601String(),
          id,
        ],
      );
      final updated = db.raw.select('SELECT * FROM pedidos WHERE id=?', [id]).first;
      return json(Pedido.fromRow(updated).toJson());
    } catch (e) {
      return json({'error': 'agendamento falhou: $e'}, status: 500);
    }
  });

  // ── Confirmar saída ───────────────────────────────────────────────────
  r.post('/<id>/saida', (Request req, String id) async {
    final body = req.url.queryParameters.isNotEmpty || req.contentLength == 0
        ? <String, dynamic>{}
        : jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final porQuem = body['entregue_por'] as String?;

    final rows = db.raw.select('SELECT id FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);

    final now = DateTime.now().toIso8601String();
    db.raw.execute(
      'UPDATE pedidos SET entregue_em=?, entregue_por=?, status=?, atualizado_em=? WHERE id=?',
      [now, porQuem, 'entregue', now, id],
    );
    final updated = db.raw.select('SELECT * FROM pedidos WHERE id=?', [id]).first;
    return json(Pedido.fromRow(updated).toJson());
  });

  // ── Duplicar ───────────────────────────────────────────────────────────
  r.post('/<id>/duplicar', (Request req, String id) async {
    final rows = db.raw.select('SELECT * FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    final orig = Pedido.fromRow(rows.first);

    final novoId = uuid.v4();
    final novoLote = db.proximoLote();
    final now = DateTime.now().toIso8601String();

    // Verificar se cliente tem ciclo de fechamento aberto para o pedido duplicado
    String? novoFechamentoId;
    if (orig.clienteId != null) {
      final fechRows = db.raw.select(
        "SELECT id FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
        [orig.clienteId],
      );
      if (fechRows.isNotEmpty) {
        novoFechamentoId = fechRows.first['id'] as String;
      }
    }

    db.raw.execute('''
      INSERT INTO pedidos (
        id, lote, cliente_id, cliente_nome, cliente_telefone, cliente_email,
        descricao, peca, tecnica, quantidade, valor,
        cor_peca, tamanho_peca, tecido,
        arte_cores, arte_tamanho_cm, arte_posicao, arte_observacao,
        data_chegada, data_producao, prazo_dias, agendamento_fixo,
        forma_entrega, endereco_entrega, data_entrega_combinada, entregue_em, entregue_por,
        forma_pagamento, valor_pago, sinal_pago, status_pagamento,
        status, urgente, observacao, fechamento_id, criado_em, atualizado_em
      ) VALUES (?,?,?,?,?,?, ?,?,?,?,?, ?,?,?, ?,?,?,?, ?,?,?,?, ?,?,?,?,?, ?,?,?,?, ?,?,?,?,?,?,?)
    ''', [
      novoId,
      novoLote,
      orig.clienteId,
      orig.clienteNome,
      orig.clienteTelefone,
      orig.clienteEmail,
      orig.descricao,
      orig.peca,
      orig.tecnica,
      orig.quantidade,
      orig.valor,
      orig.corPeca,
      orig.tamanhoPeca,
      orig.tecido,
      orig.arteCores,
      orig.arteTamanhoCm,
      orig.artePosicao,
      orig.arteObservacao,
      null, // data_chegada
      null, // data_producao
      null, // prazo_dias
      0,
      orig.formaEntrega,
      orig.enderecoEntrega,
      null, // data_entrega_combinada
      null, // entregue_em
      null, // entregue_por
      orig.formaPagamento,
      0, // valor_pago
      0, // sinal_pago
      'devendo',
      'pendente',
      orig.urgente ? 1 : 0,
      orig.observacao,
      novoFechamentoId,
      now,
      now,
    ]);

    final created = db.raw.select('SELECT * FROM pedidos WHERE id = ?', [novoId]).first;
    return json(Pedido.fromRow(created).toJson(), status: 201);
  });

  return r;
}

String _formatarData(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
