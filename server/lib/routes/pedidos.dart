import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../agendador.dart';
import '../db.dart';
import '../logger.dart';
import '../models/pedido.dart';
import '../pagamentos_util.dart';
import '../validators.dart';

/// Colunas explícitas (M-10) — manter em sincronia com `Pedido.fromRow`.
const String _pedidoCols =
    'id, lote, cliente_id, cliente_nome, cliente_telefone, cliente_email, '
    'descricao, peca, tecnica, quantidade, valor, '
    'cor_peca, tamanho_peca, tecido, '
    'arte_cores, arte_tamanho_cm, arte_posicao, arte_observacao, '
    'data_chegada, data_producao, prazo_dias, agendamento_fixo, '
    'forma_entrega, endereco_entrega, data_entrega_combinada, entregue_em, entregue_por, '
    'forma_pagamento, valor_pago, sinal_pago, status_pagamento, '
    'status, urgente, observacao, regiao, tipo_peca, fechamento_id, criado_em, atualizado_em';

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

    final sql = StringBuffer('SELECT $_pedidoCols FROM pedidos');
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
    final rows = db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    return json(Pedido.fromRow(rows.first).toJson());
  });

  // ── Criar ──────────────────────────────────────────────────────────────
  r.post('/', (Request req) async {
    final rawBody = await req.readAsString();
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }

    final erro = validarPedido(body, criar: true);
    if (erro != null) {
      requestLog.info('POST /pedidos 400 $erro');
      return json({'error': erro}, status: 400);
    }

    final clienteNome = (body['cliente_nome'] as String).trim();
    final descricao = (body['descricao'] as String).trim();
    final valor = (body['valor'] as num).toDouble();

    String? clienteId = body['cliente_id'] as String?;
    if (clienteId == null && clienteNome.isNotEmpty) {
      final m = db.raw.select(
        'SELECT id FROM clientes WHERE lower(nome) = lower(?) LIMIT 2',
        [clienteNome],
      );
      if (m.length == 1) clienteId = m.first['id'] as String;
    }

    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final urgente = (body['urgente'] == true) ? 1 : 0;
    final agendamentoFixo = (body['agendamento_fixo'] == true) ? 1 : 0;

    final Map<String, dynamic> pedido;
    try {
      pedido = db.transaction(() {
      final lote = db.proximoLote();

      String? fechamentoId;
      if (clienteId != null) {
        final fechRows = db.raw.select(
          "SELECT id FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
          [clienteId],
        );
        if (fechRows.isNotEmpty) fechamentoId = fechRows.first['id'] as String;
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
          status, urgente, observacao, regiao, tipo_peca, fechamento_id, criado_em, atualizado_em
        ) VALUES (?,?,?,?,?, ?,?,?,?,?, ?,?,?, ?,?,?,?, ?,?,?,?, ?,?,?,?,?, ?,?,?,?, ?,?,?,?,?,?,?,?,?)
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
        agendamentoFixo,
        body['forma_entrega'],
        body['endereco_entrega'],
        body['data_entrega_combinada'],
        body['entregue_em'],
        body['entregue_por'],
        body['forma_pagamento'],
        0, // valor_pago — só muda via /pagamentos (C-03)
        (body['sinal_pago'] as num?)?.toDouble() ?? 0,
        body['status_pagamento'] ?? 'devendo',
        body['status'] ?? 'pendente',
        urgente,
        body['observacao'],
        body['regiao'],
        body['tipo_peca'],
        fechamentoId,
        now,
        now,
      ]);

      if (fechamentoId != null) {
        _atualizarAgregadoFechamento(db, fechamentoId, now);
      }

      // Recalcula status_pagamento (vai virar 'devendo' já que valor_pago=0).
      recalcularPagamento(db.raw, id);

      // Agendamento, ainda dentro da transação — qualquer erro reverte o INSERT.
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
            'UPDATE pedidos SET data_producao=?, prazo_dias=?, '
            "status=CASE WHEN status='pendente' THEN 'agendado' ELSE status END "
            'WHERE id=?',
            [_formatarData(inicio), prazoDias, id],
          );
        } on AgendadorCapacidadeException catch (e) {
          // Capacidade insuficiente é erro de regra de negócio — sobe pra 400.
          throw _BadRequest(e.message);
        }
      }

      return db.raw
          .select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [id]).first;
      });
    } on _BadRequest catch (e) {
      return json({'error': e.message}, status: 400);
    } on AgendadorCapacidadeException catch (e) {
      return json({'error': e.message}, status: 400);
    }

    return json(Pedido.fromRow(pedido).toJson(), status: 201);
  });

  // ── Atualizar ──────────────────────────────────────────────────────────
  r.put('/<id>', (Request req, String id) async {
    final exists = db.raw.select('SELECT id FROM pedidos WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }

    final erro = validarPedido(body, criar: false);
    if (erro != null) return json({'error': erro}, status: 400);

    // Campos editáveis — valor_pago removido (C-03); só muda via /pagamentos.
    const editaveis = {
      'cliente_id', 'cliente_nome', 'cliente_telefone', 'cliente_email',
      'descricao', 'peca', 'tecnica', 'quantidade', 'valor',
      'cor_peca', 'tamanho_peca', 'tecido',
      'arte_cores', 'arte_tamanho_cm', 'arte_posicao', 'arte_observacao',
      'data_chegada', 'data_producao', 'prazo_dias', 'agendamento_fixo',
      'forma_entrega', 'endereco_entrega', 'data_entrega_combinada', 'entregue_em', 'entregue_por',
      'forma_pagamento', 'sinal_pago', 'status_pagamento',
      'status', 'urgente', 'observacao', 'regiao', 'tipo_peca', 'fechamento_id',
    };

    final sets = <String>[];
    final args = <Object?>[];
    for (final campo in editaveis) {
      if (!body.containsKey(campo)) continue;
      var valor = body[campo];
      if (campo == 'urgente' || campo == 'agendamento_fixo') {
        valor = (valor == true) ? 1 : 0;
      }
      if ((campo == 'valor' || campo == 'sinal_pago') && valor is num) {
        valor = valor.toDouble();
      }
      sets.add('$campo = ?');
      args.add(valor);
    }

    db.transaction(() {
      if (sets.isNotEmpty) {
        sets.add('atualizado_em = ?');
        args.add(DateTime.now().toUtc().toIso8601String());
        args.add(id);
        db.raw.execute('UPDATE pedidos SET ${sets.join(', ')} WHERE id = ?', args);
      }
      if (body.containsKey('valor')) {
        recalcularPagamento(db.raw, id);
      }
      // Reflete agregado caso valor tenha mudado e o pedido pertença a fechamento.
      final fech = db.raw.select(
        'SELECT fechamento_id FROM pedidos WHERE id = ?',
        [id],
      ).first;
      final fechamentoId = fech['fechamento_id'] as String?;
      if (fechamentoId != null && body.containsKey('valor')) {
        _atualizarAgregadoFechamento(
          db,
          fechamentoId,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
    });

    final updated = db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [id]).first;
    return json(Pedido.fromRow(updated).toJson());
  });

  // ── Deletar ────────────────────────────────────────────────────────────
  r.delete('/<id>', (Request req, String id) {
    final exists = db.raw.select(
      'SELECT id, fechamento_id FROM pedidos WHERE id = ?',
      [id],
    );
    if (exists.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    final fechamentoId = exists.first['fechamento_id'] as String?;

    db.transaction(() {
      db.raw.execute('DELETE FROM pedidos WHERE id = ?', [id]);
      if (fechamentoId != null) {
        _atualizarAgregadoFechamento(
          db,
          fechamentoId,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
    });
    return json({'ok': true});
  });

  // ── Agendar automaticamente ───────────────────────────────────────────
  r.post('/<id>/agendar', (Request req, String id) async {
    final rows = db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    final p = Pedido.fromRow(rows.first);
    if (p.status == 'entregue' || p.entregueEm != null) {
      return json({'error': 'pedido já foi entregue — não pode reagendar'}, status: 400);
    }
    if (p.valor <= 0) {
      return json({'error': 'pedido sem valor — não pode agendar'}, status: 400);
    }
    // A-03: se está fixado, não reagendar — mantém data atual.
    if (p.agendamentoFixo) {
      return json({
        'error': 'pedido tem agendamento fixo — desmarque antes de reagendar',
      }, status: 409);
    }

    final dc = p.dataChegada != null ? DateTime.tryParse(p.dataChegada!) : null;
    try {
      final updated = db.transaction(() {
        final inicio = agendador.agendar(pedidoId: id, valor: p.valor, dataChegada: dc);
        final prazo = dc != null ? agendador.calcularPrazoDias(dc, inicio) : null;
        db.raw.execute(
          'UPDATE pedidos SET data_producao=?, prazo_dias=?, '
          "status=CASE WHEN status='pendente' THEN 'agendado' ELSE status END, "
          'atualizado_em=? WHERE id=?',
          [
            _formatarData(inicio),
            prazo,
            DateTime.now().toUtc().toIso8601String(),
            id,
          ],
        );
        return db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id=?', [id]).first;
      });
      return json(Pedido.fromRow(updated).toJson());
    } on AgendadorCapacidadeException catch (e) {
      return json({'error': e.message}, status: 400);
    } catch (e, st) {
      agendaLog.severe('agendamento falhou pedido=$id', e, st);
      return json({'error': 'agendamento falhou'}, status: 500);
    }
  });

  // ── Confirmar saída ───────────────────────────────────────────────────
  r.post('/<id>/saida', (Request req, String id) async {
    final raw = await req.readAsString();
    final body = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final porQuem = body['entregue_por'] as String?;

    final rows = db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    final p = Pedido.fromRow(rows.first);
    if (p.status == 'entregue' || p.entregueEm != null) {
      return json({'error': 'pedido já foi entregue'}, status: 400);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    db.raw.execute(
      'UPDATE pedidos SET entregue_em=?, entregue_por=?, status=?, atualizado_em=? WHERE id=?',
      [now, porQuem, 'entregue', now, id],
    );
    final updated = db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id=?', [id]).first;
    return json(Pedido.fromRow(updated).toJson());
  });

  // ── Duplicar ───────────────────────────────────────────────────────────
  r.post('/<id>/duplicar', (Request req, String id) async {
    final rows = db.raw.select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'pedido não encontrado'}, status: 404);
    final orig = Pedido.fromRow(rows.first);

    final now = DateTime.now().toUtc().toIso8601String();
    final created = db.transaction(() {
      final novoId = uuid.v4();
      final novoLote = db.proximoLote();

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
          status, urgente, observacao, regiao, tipo_peca, fechamento_id, criado_em, atualizado_em
        ) VALUES (?,?,?,?,?, ?,?,?,?,?, ?,?,?, ?,?,?,?, ?,?,?,?, ?,?,?,?,?, ?,?,?,?, ?,?,?,?,?,?,?,?,?)
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
        null, null, null, 0,
        orig.formaEntrega,
        orig.enderecoEntrega,
        null, null, null,
        orig.formaPagamento,
        0, 0, 'devendo',
        'pendente',
        orig.urgente ? 1 : 0,
        orig.observacao,
        orig.regiao,
        orig.tipoPeca,
        novoFechamentoId,
        now,
        now,
      ]);

      if (novoFechamentoId != null) {
        _atualizarAgregadoFechamento(db, novoFechamentoId, now);
      }

      return db.raw
          .select('SELECT $_pedidoCols FROM pedidos WHERE id = ?', [novoId]).first;
    });

    return json(Pedido.fromRow(created).toJson(), status: 201);
  });

  return r;
}

void _atualizarAgregadoFechamento(Db db, String fechamentoId, String nowIso) {
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
    nowIso,
    fechamentoId,
  ]);
}

String _formatarData(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Erro lançado dentro da transação pra disparar rollback + retorno 400.
class _BadRequest implements Exception {
  final String message;
  _BadRequest(this.message);
  @override
  String toString() => message;
}
