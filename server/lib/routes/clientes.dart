import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../dinheiro.dart';
import '../fechamentos_util.dart';
import '../models/cliente.dart';
import '../models/cliente_fechamento.dart';
import '../models/pedido.dart';
import '../validators.dart';

const String _clienteCols =
    'id, nome, telefone, email, endereco, observacao, '
    'fechamento_tipo, fechamento_dia, fechamento_data_fixa, fechamento_ativo, '
    'criado_em, atualizado_em';

const String _fechamentoCols =
    'id, cliente_id, numero, data_abertura, data_fechamento_prevista, '
    'data_fechamento_real, status, total_pedidos, valor_total, valor_pago, '
    'observacao, criado_em, atualizado_em';

const String _pedidoColsClientes =
    'id, lote, cliente_id, cliente_nome, cliente_telefone, cliente_email, '
    'descricao, peca, tecnica, quantidade, valor, '
    'cor_peca, tamanho_peca, tecido, '
    'arte_cores, arte_tamanho_cm, arte_posicao, arte_observacao, '
    'data_chegada, data_producao, prazo_dias, agendamento_fixo, '
    'forma_entrega, endereco_entrega, data_entrega_combinada, entregue_em, entregue_por, '
    'forma_pagamento, valor_pago, sinal_pago, status_pagamento, '
    'status, urgente, observacao, regiao, tipo_peca, fechamento_id, criado_em, atualizado_em';

Router clientesRouter(Db db) {
  final r = Router();
  const uuid = Uuid();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/', (Request req) {
    final qp = req.url.queryParameters;
    final busca = qp['busca'];
    final comDebito = qp['com_debito'] == 'true';
    final ordenar = qp['ordenar'] ?? 'nome';

    final where = <String>[];
    final args = <Object?>[];
    if (busca != null && busca.isNotEmpty) {
      where.add('(c.nome LIKE ? OR c.telefone LIKE ?)');
      args.addAll(['%$busca%', '%$busca%']);
    }

    final sql = StringBuffer(
      'SELECT ${_clienteCols.split(", ").map((c) => "c.$c").join(", ")}, '
      '(SELECT COUNT(*) FROM pedidos p WHERE p.cliente_id = c.id) AS total_pedidos, '
      '(SELECT COALESCE(SUM(valor), 0) FROM pedidos p WHERE p.cliente_id = c.id) AS total_gasto, '
      '(SELECT COALESCE(SUM(valor - valor_pago), 0) FROM pedidos p '
      "  WHERE p.cliente_id = c.id AND p.status_pagamento != 'pago') AS valor_devendo "
      'FROM clientes c',
    );
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');

    final ordemSql = switch (ordenar) {
      'gasto' => 'total_gasto DESC',
      'devendo' => 'valor_devendo DESC',
      'pedidos' => 'total_pedidos DESC',
      'recente' => 'c.criado_em DESC',
      _ => 'c.nome COLLATE NOCASE',
    };
    sql.write(' ORDER BY $ordemSql');

    // M-07: paginação defensiva (limit=200 default, max=1000). Body permanece
    // array; total filtrado vai em X-Total-Count. v1 = offset-based; cursor
    // fica para follow-up. NB: o filtro `com_debito` é aplicado em-memória
    // após o LIMIT, então o total reportado é antes do filtro pós-SQL — é o
    // melhor disponível sem mover `com_debito` para o WHERE (que exigiria
    // refator do agregado). Documentado.
    final limite = _parseLimit(qp['limit']);
    final offset = _parseOffset(qp['offset']);

    final whereSqlCount = where.isNotEmpty ? ' WHERE ${where.join(' AND ')}' : '';
    final totalRow = db.raw.select(
      'SELECT COUNT(*) AS n FROM clientes c$whereSqlCount',
      args,
    );
    final total = (totalRow.first['n'] as num).toInt();

    sql.write(' LIMIT ? OFFSET ?');
    final rows = db.raw.select(sql.toString(), [...args, limite, offset]);
    final filtrado = comDebito
        ? rows.where((r) => ehMaiorQueZero((r['valor_devendo'] as num).toDouble()))
        : rows;
    return Response(
      200,
      body: jsonEncode(filtrado.map((row) {
        final c = Cliente.fromRow(row);
        return {
          ...c.toJson(),
          'total_pedidos': row['total_pedidos'],
          'total_gasto': (row['total_gasto'] as num).toDouble(),
          'valor_devendo': (row['valor_devendo'] as num).toDouble(),
        };
      }).toList()),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'x-total-count': '$total',
      },
    );
  });

  r.get('/<id>', (Request req, String id) {
    final rows = db.raw.select('SELECT $_clienteCols FROM clientes WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);
    final c = Cliente.fromRow(rows.first);

    final pedidoRows = db.raw.select(
      'SELECT $_pedidoColsClientes FROM pedidos WHERE cliente_id = ? ORDER BY criado_em DESC',
      [id],
    );
    final pedidos = pedidoRows.map((p) => Pedido.fromRow(p).toJson()).toList();
    final totalGasto = pedidoRows.fold<double>(
      0,
      (s, p) => s + (p['valor'] as num).toDouble(),
    );
    final valorDevendo = pedidoRows.fold<double>(0, (s, p) {
      final st = p['status_pagamento'] as String? ?? 'devendo';
      if (st == 'pago') return s;
      final v = (p['valor'] as num).toDouble();
      final pago = ((p['valor_pago'] as num?) ?? 0).toDouble();
      return s + (v - pago);
    });

    Map<String, dynamic>? fechamentoAtual;
    if (c.fechamentoAtivo) {
      final fechRows = db.raw.select(
        "SELECT $_fechamentoCols FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
        [id],
      );
      if (fechRows.isNotEmpty) {
        fechamentoAtual = ClienteFechamento.fromRow(fechRows.first).toJson();
      }
    }

    return json({
      ...c.toJson(),
      'pedidos': pedidos,
      'total_pedidos': pedidos.length,
      'total_gasto': totalGasto,
      'valor_devendo': valorDevendo,
      if (fechamentoAtual != null) 'fechamento_atual': fechamentoAtual,
    });
  });

  r.post('/', (Request req) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }
    final erro = validarCliente(body, criar: true);
    if (erro != null) return json({'error': erro}, status: 400);

    final nome = (body['nome'] as String).trim();
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final fechamentoAtivo = (body['fechamento_ativo'] == true) ? 1 : 0;

    final clienteResp = db.transaction(() {
      db.raw.execute(
        'INSERT INTO clientes (id, nome, telefone, email, endereco, observacao, '
        'fechamento_tipo, fechamento_dia, fechamento_data_fixa, fechamento_ativo, '
        'criado_em, atualizado_em) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          nome,
          body['telefone'],
          body['email'],
          body['endereco'],
          body['observacao'],
          body['fechamento_tipo'],
          body['fechamento_dia'],
          body['fechamento_data_fixa'],
          fechamentoAtivo,
          now,
          now,
        ],
      );

      final created = db.raw
          .select('SELECT $_clienteCols FROM clientes WHERE id = ?', [id]).first;
      final cliente = Cliente.fromRow(created);

      if (cliente.fechamentoAtivo && cliente.fechamentoTipo != null) {
        criarFechamentoInicial(db, cliente, retroativo: false);
      }

      Map<String, dynamic>? fechamentoAtual;
      final fechRows = db.raw.select(
        "SELECT $_fechamentoCols FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
        [id],
      );
      if (fechRows.isNotEmpty) {
        fechamentoAtual = ClienteFechamento.fromRow(fechRows.first).toJson();
      }
      return {
        ...cliente.toJson(),
        if (fechamentoAtual != null) 'fechamento_atual': fechamentoAtual,
      };
    });

    return json(clienteResp, status: 201);
  });

  r.put('/<id>', (Request req, String id) async {
    final exists = db.raw.select('SELECT id FROM clientes WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }
    final erro = validarCliente(body, criar: false);
    if (erro != null) return json({'error': erro}, status: 400);

    const editaveis = {
      'nome', 'telefone', 'email', 'endereco', 'observacao',
      'fechamento_tipo', 'fechamento_dia', 'fechamento_data_fixa',
    };
    final sets = <String>[];
    final args = <Object?>[];
    for (final campo in editaveis) {
      if (!body.containsKey(campo)) continue;
      if (campo == 'fechamento_dia' && body[campo] is! int?) continue;
      sets.add('$campo = ?');
      args.add(body[campo]);
    }

    bool fechamentoAtivoAntes = false;
    if (body.containsKey('fechamento_ativo')) {
      sets.add('fechamento_ativo = ?');
      args.add((body['fechamento_ativo'] == true) ? 1 : 0);
      final prevRows = db.raw.select('SELECT fechamento_ativo FROM clientes WHERE id = ?', [id]);
      fechamentoAtivoAntes = (prevRows.first['fechamento_ativo'] as int?) == 1;
    }

    db.transaction(() {
      if (sets.isNotEmpty) {
        sets.add('atualizado_em = ?');
        args.add(DateTime.now().toUtc().toIso8601String());
        args.add(id);
        db.raw.execute('UPDATE clientes SET ${sets.join(', ')} WHERE id = ?', args);
      }

      // B-02: rename do cliente propaga para o denormalizado `cliente_nome`
      // em pedidos vinculados (cliente_id = id). Pedidos com cliente_id NULL
      // (cliente apagado) preservam o snapshot — comportamento intencional.
      if (body.containsKey('nome')) {
        db.raw.execute(
          'UPDATE pedidos SET cliente_nome = ? WHERE cliente_id = ?',
          [body['nome'], id],
        );
      }

      final fechamentoAtivoNovo = body['fechamento_ativo'] == true;
      if (fechamentoAtivoNovo && !fechamentoAtivoAntes) {
        final updatedRows = db.raw.select('SELECT $_clienteCols FROM clientes WHERE id = ?', [id]);
        final cliente = Cliente.fromRow(updatedRows.first);
        if (cliente.fechamentoTipo != null) {
          criarFechamentoInicial(db, cliente, retroativo: true);
        }
      }
    });

    final updated = db.raw.select('SELECT $_clienteCols FROM clientes WHERE id = ?', [id]).first;
    return json(Cliente.fromRow(updated).toJson());
  });

  r.delete('/<id>', (Request req, String id) {
    final exists = db.raw.select('SELECT id FROM clientes WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);
    db.raw.execute('DELETE FROM clientes WHERE id = ?', [id]);
    return json({'ok': true});
  });

  // ── Fechamentos do cliente ────────────────────────────────────────────

  r.get('/<id>/fechamentos', (Request req, String id) {
    final clienteRows = db.raw.select('SELECT id FROM clientes WHERE id = ?', [id]);
    if (clienteRows.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);

    final rows = db.raw.select(
      'SELECT $_fechamentoCols FROM cliente_fechamentos WHERE cliente_id = ? ORDER BY numero DESC',
      [id],
    );
    return json(rows.map((row) => ClienteFechamento.fromRow(row).toJson()).toList());
  });

  r.get('/<id>/fechamentos/<fechamentoId>', (Request req, String id, String fechamentoId) {
    final rows = db.raw.select(
      'SELECT $_fechamentoCols FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, id],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);
    final pedidoRows = db.raw.select(
      'SELECT $_pedidoColsClientes FROM pedidos WHERE fechamento_id = ? ORDER BY criado_em DESC',
      [fechamentoId],
    );
    final pedidos = pedidoRows.map((p) => Pedido.fromRow(p).toJson()).toList();

    return json({
      ...fechamento.toJson(),
      'pedidos': pedidos,
    });
  });

  r.post('/<id>/fechamentos/<fechamentoId>/fechar',
      (Request req, String id, String fechamentoId) async {
    final rows = db.raw.select(
      'SELECT $_fechamentoCols FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, id],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);
    if (fechamento.status == 'fechado') {
      return json({'error': 'fechamento já está fechado'}, status: 400);
    }

    final rawBody = await req.readAsString();
    final body = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;
    final observacao = body['observacao'] as String?;

    final now = DateTime.now();
    final nowIso = now.toUtc().toIso8601String();

    db.transaction(() {
      final agg = db.raw.select(
        'SELECT COUNT(*) AS total, COALESCE(SUM(valor), 0) AS vt, COALESCE(SUM(valor_pago), 0) AS vp '
        'FROM pedidos WHERE fechamento_id = ?',
        [fechamentoId],
      ).first;

      db.raw.execute('''
        UPDATE cliente_fechamentos
        SET status = 'fechado',
            data_fechamento_real = ?,
            total_pedidos = ?,
            valor_total = ?,
            valor_pago = ?,
            observacao = COALESCE(?, observacao),
            atualizado_em = ?
        WHERE id = ?
      ''', [
        nowIso,
        agg['total'] as int,
        (agg['vt'] as num).toDouble(),
        (agg['vp'] as num).toDouble(),
        observacao,
        nowIso,
        fechamentoId,
      ]);

      final clienteRows = db.raw.select('SELECT $_clienteCols FROM clientes WHERE id = ?', [id]);
      final cliente = Cliente.fromRow(clienteRows.first);
      if (cliente.fechamentoAtivo && cliente.fechamentoTipo != null) {
        criarProximoCiclo(db, cliente, now);
      }
    });

    final updated = db.raw.select(
      'SELECT $_fechamentoCols FROM cliente_fechamentos WHERE id = ?',
      [fechamentoId],
    ).first;
    return json(ClienteFechamento.fromRow(updated).toJson());
  });

  r.post('/<id>/fechamentos/<fechamentoId>/estender',
      (Request req, String id, String fechamentoId) async {
    final rows = db.raw.select(
      'SELECT $_fechamentoCols FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, id],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);
    if (fechamento.status == 'fechado') {
      return json({'error': 'fechamento já está fechado'}, status: 400);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return json({'error': 'body inválido'}, status: 400);
    }
    final novaData = body['nova_data'] as String?;
    if (novaData == null || novaData.isEmpty) {
      return json({'error': 'nova_data é obrigatória (YYYY-MM-DD)'}, status: 400);
    }

    final novaDataParsed = DateTime.tryParse(novaData);
    final dataAtualParsed = DateTime.tryParse(fechamento.dataFechamentoPrevista);
    // A-02: aceita só datas estritamente posteriores (`!isAfter` cobre igual+anterior).
    if (novaDataParsed != null &&
        dataAtualParsed != null &&
        !novaDataParsed.isAfter(dataAtualParsed)) {
      return json({'error': 'nova_data deve ser posterior à data prevista atual'}, status: 400);
    }

    final observacao = body['observacao'] as String?;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    db.raw.execute('''
      UPDATE cliente_fechamentos
      SET status = 'estendido',
          data_fechamento_prevista = ?,
          observacao = COALESCE(?, observacao),
          atualizado_em = ?
      WHERE id = ?
    ''', [
      novaData,
      observacao,
      nowIso,
      fechamentoId,
    ]);

    final updated = db.raw.select(
      'SELECT $_fechamentoCols FROM cliente_fechamentos WHERE id = ?',
      [fechamentoId],
    ).first;
    return json(ClienteFechamento.fromRow(updated).toJson());
  });

  return r;
}

// M-07: paginação defensiva. Valores inválidos caem em defaults silenciosos
// (não 400) para máxima compatibilidade com clients antigos.
const int _kDefaultLimit = 200;
const int _kMaxLimit = 1000;

int _parseLimit(String? raw) {
  if (raw == null || raw.isEmpty) return _kDefaultLimit;
  final n = int.tryParse(raw);
  if (n == null || n <= 0) return _kDefaultLimit;
  return n > _kMaxLimit ? _kMaxLimit : n;
}

int _parseOffset(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  final n = int.tryParse(raw);
  if (n == null || n < 0) return 0;
  return n;
}
