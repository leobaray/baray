import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/cliente.dart';
import '../models/cliente_fechamento.dart';
import '../models/pedido.dart';
import 'cliente_fechamentos.dart' show criarFechamentoInicial, criarProximoCiclo;

Router clientesRouter(Db db) {
  final r = Router();
  const uuid = Uuid();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  r.get('/', (Request req) {
    final busca = req.url.queryParameters['busca'];
    final sql = StringBuffer('SELECT c.*, '
        '(SELECT COUNT(*) FROM pedidos p WHERE p.cliente_id = c.id) AS total_pedidos, '
        '(SELECT COALESCE(SUM(valor), 0) FROM pedidos p WHERE p.cliente_id = c.id) AS total_gasto '
        'FROM clientes c');
    final args = <Object?>[];
    if (busca != null && busca.isNotEmpty) {
      sql.write(' WHERE c.nome LIKE ? OR c.telefone LIKE ?');
      args.addAll(['%$busca%', '%$busca%']);
    }
    sql.write(' ORDER BY c.nome');

    final rows = db.raw.select(sql.toString(), args);
    return json(rows.map((row) {
      final c = Cliente.fromRow(row);
      return {
        ...c.toJson(),
        'total_pedidos': row['total_pedidos'],
        'total_gasto': (row['total_gasto'] as num).toDouble(),
      };
    }).toList());
  });

  r.get('/<id>', (Request req, String id) {
    final rows = db.raw.select('SELECT * FROM clientes WHERE id = ?', [id]);
    if (rows.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);
    final c = Cliente.fromRow(rows.first);

    final pedidoRows = db.raw.select(
      'SELECT * FROM pedidos WHERE cliente_id = ? ORDER BY criado_em DESC',
      [id],
    );
    final pedidos = pedidoRows.map((p) => Pedido.fromRow(p).toJson()).toList();
    final totalGasto = pedidoRows.fold<double>(
      0,
      (s, p) => s + (p['valor'] as num).toDouble(),
    );

    // Buscar fechamento atual (aberto ou estendido)
    Map<String, dynamic>? fechamentoAtual;
    if (c.fechamentoAtivo) {
      final fechRows = db.raw.select(
        "SELECT * FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
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
      if (fechamentoAtual != null) 'fechamento_atual': fechamentoAtual,
    });
  });

  r.post('/', (Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final nome = (body['nome'] as String?)?.trim();
    if (nome == null || nome.isEmpty) {
      return json({'error': 'nome é obrigatório'}, status: 400);
    }

    final id = uuid.v4();
    final now = DateTime.now().toIso8601String();

    final fechamentoTipo = body['fechamento_tipo'] as String?;
    final fechamentoDia = body['fechamento_dia'] as int?;
    final fechamentoDataFixa = body['fechamento_data_fixa'] as String?;
    final fechamentoAtivo = (body['fechamento_ativo'] == true) ? 1 : 0;

    db.raw.execute(
      'INSERT INTO clientes (id, nome, telefone, email, endereco, observacao, fechamento_tipo, fechamento_dia, fechamento_data_fixa, fechamento_ativo, criado_em, atualizado_em) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        nome,
        body['telefone'],
        body['email'],
        body['endereco'],
        body['observacao'],
        fechamentoTipo,
        fechamentoDia,
        fechamentoDataFixa,
        fechamentoAtivo,
        now,
        now,
      ],
    );
    final created = db.raw.select('SELECT * FROM clientes WHERE id = ?', [id]).first;
    final cliente = Cliente.fromRow(created);

    // Se fechamento ativo, criar primeiro ciclo
    if (cliente.fechamentoAtivo && cliente.fechamentoTipo != null) {
      criarFechamentoInicial(db, cliente, retroativo: false);
    }

    // Retornar com fechamento_atual
    Map<String, dynamic>? fechamentoAtual;
    final fechRows = db.raw.select(
      "SELECT * FROM cliente_fechamentos WHERE cliente_id = ? AND status IN ('aberto', 'estendido') ORDER BY numero DESC LIMIT 1",
      [id],
    );
    if (fechRows.isNotEmpty) {
      fechamentoAtual = ClienteFechamento.fromRow(fechRows.first).toJson();
    }

    return json({
      ...cliente.toJson(),
      if (fechamentoAtual != null) 'fechamento_atual': fechamentoAtual,
    }, status: 201);
  });

  r.put('/<id>', (Request req, String id) async {
    final exists = db.raw.select('SELECT id FROM clientes WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

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

    // Tratamento especial para fechamento_ativo (bool → int)
    bool fechamentoAtivoAntes = false;
    if (body.containsKey('fechamento_ativo')) {
      sets.add('fechamento_ativo = ?');
      args.add((body['fechamento_ativo'] == true) ? 1 : 0);

      // Verificar se estava desativado antes e agora será ativado
      final prevRows = db.raw.select('SELECT fechamento_ativo FROM clientes WHERE id = ?', [id]);
      fechamentoAtivoAntes = (prevRows.first['fechamento_ativo'] as int?) == 1;
    }

    if (sets.isNotEmpty) {
      sets.add('atualizado_em = ?');
      args.add(DateTime.now().toIso8601String());
      args.add(id);
      db.raw.execute('UPDATE clientes SET ${sets.join(', ')} WHERE id = ?', args);
    }

    // Sincronizar nome nos pedidos do cliente
    if (body.containsKey('nome')) {
      db.raw.execute(
        'UPDATE pedidos SET cliente_nome = ? WHERE cliente_id = ?',
        [body['nome'], id],
      );
    }

    // Se fechamento foi recém-ativado, criar ciclo retroativo
    final fechamentoAtivoNovo = body['fechamento_ativo'] == true;
    if (fechamentoAtivoNovo && !fechamentoAtivoAntes) {
      final updatedRows = db.raw.select('SELECT * FROM clientes WHERE id = ?', [id]);
      final cliente = Cliente.fromRow(updatedRows.first);
      if (cliente.fechamentoTipo != null) {
        criarFechamentoInicial(db, cliente, retroativo: true);
      }
    }

    final updated = db.raw.select('SELECT * FROM clientes WHERE id = ?', [id]).first;
    return json(Cliente.fromRow(updated).toJson());
  });

  r.delete('/<id>', (Request req, String id) {
    final exists = db.raw.select('SELECT id FROM clientes WHERE id = ?', [id]);
    if (exists.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);
    db.raw.execute('DELETE FROM clientes WHERE id = ?', [id]);
    return json({'ok': true});
  });

  // ── Rotas de Fechamentos (inline pois shelf_router mount não suporta params) ──

  // GET /<id>/fechamentos — listar
  r.get('/<id>/fechamentos', (Request req, String id) {
    final clienteRows = db.raw.select('SELECT * FROM clientes WHERE id = ?', [id]);
    if (clienteRows.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);

    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE cliente_id = ? ORDER BY numero DESC',
      [id],
    );
    return json(rows.map((row) => ClienteFechamento.fromRow(row).toJson()).toList());
  });

  // GET /<id>/fechamentos/<fechamentoId> — detalhe com pedidos
  r.get('/<id>/fechamentos/<fechamentoId>', (Request req, String id, String fechamentoId) {
    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, id],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);
    final pedidoRows = db.raw.select(
      'SELECT * FROM pedidos WHERE fechamento_id = ? ORDER BY criado_em DESC',
      [fechamentoId],
    );
    final pedidos = pedidoRows.map((p) => Pedido.fromRow(p).toJson()).toList();

    return json({
      ...fechamento.toJson(),
      'pedidos': pedidos,
    });
  });

  // POST /<id>/fechamentos/<fechamentoId>/fechar — fechar ciclo
  r.post('/<id>/fechamentos/<fechamentoId>/fechar', (Request req, String id, String fechamentoId) async {
    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, id],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);
    if (fechamento.status == 'fechado') {
      return json({'error': 'fechamento já está fechado'}, status: 400);
    }

    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>?;
    final observacao = body?['observacao'] as String?;

    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // Recalcular agregados a partir dos pedidos
    final agg = db.raw.select(
      'SELECT COUNT(*) as total, COALESCE(SUM(valor), 0) as vt, COALESCE(SUM(valor_pago), 0) as vp '
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

    // Auto-criar próximo ciclo
    final clienteRows = db.raw.select('SELECT * FROM clientes WHERE id = ?', [id]);
    final cliente = Cliente.fromRow(clienteRows.first);

    if (cliente.fechamentoAtivo && cliente.fechamentoTipo != null) {
      criarProximoCiclo(db, cliente, now);
    }

    final updated = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ?',
      [fechamentoId],
    ).first;
    return json(ClienteFechamento.fromRow(updated).toJson());
  });

  // POST /<id>/fechamentos/<fechamentoId>/estender — estender prazo
  r.post('/<id>/fechamentos/<fechamentoId>/estender', (Request req, String id, String fechamentoId) async {
    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, id],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);
    if (fechamento.status == 'fechado') {
      return json({'error': 'fechamento já está fechado'}, status: 400);
    }

    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final novaData = body['nova_data'] as String?;
    if (novaData == null || novaData.isEmpty) {
      return json({'error': 'nova_data é obrigatória (YYYY-MM-DD)'}, status: 400);
    }

    final novaDataParsed = DateTime.tryParse(novaData);
    final dataAtualParsed = DateTime.tryParse(fechamento.dataFechamentoPrevista);
    if (novaDataParsed != null && dataAtualParsed != null && novaDataParsed.isBefore(dataAtualParsed)) {
      return json({'error': 'nova_data deve ser posterior à data prevista atual'}, status: 400);
    }

    final observacao = body['observacao'] as String?;
    final nowIso = DateTime.now().toIso8601String();

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
      'SELECT * FROM cliente_fechamentos WHERE id = ?',
      [fechamentoId],
    ).first;
    return json(ClienteFechamento.fromRow(updated).toJson());
  });

  return r;
}