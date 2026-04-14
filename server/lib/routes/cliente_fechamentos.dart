import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/cliente.dart';
import '../models/cliente_fechamento.dart';
import '../models/pedido.dart';

Router clienteFechamentosRouter(Db db) {
  final r = Router();

  Response json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  // ── Listar fechamentos do cliente ──────────────────────────────────────
  r.get('/', (Request req, String clienteId) {
    final clienteRows = db.raw.select('SELECT * FROM clientes WHERE id = ?', [clienteId]);
    if (clienteRows.isEmpty) return json({'error': 'cliente não encontrado'}, status: 404);

    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE cliente_id = ? ORDER BY numero DESC',
      [clienteId],
    );
    return json(rows.map((row) => ClienteFechamento.fromRow(row).toJson()).toList());
  });

  // ── Detalhe do fechamento (com pedidos do período) ────────────────────
  r.get('/<fechamentoId>', (Request req, String clienteId, String fechamentoId) {
    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, clienteId],
    );
    if (rows.isEmpty) return json({'error': 'fechamento não encontrado'}, status: 404);

    final fechamento = ClienteFechamento.fromRow(rows.first);

    // Buscar pedidos associados a este fechamento
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

  // ── Fechar fechamento (antecipar ou no prazo) ─────────────────────────
  r.post('/<fechamentoId>/fechar', (Request req, String clienteId, String fechamentoId) async {
    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, clienteId],
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
    final clienteRows = db.raw.select('SELECT * FROM clientes WHERE id = ?', [clienteId]);
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

  // ── Estender fechamento (postergar prazo) ─────────────────────────────
  r.post('/<fechamentoId>/estender', (Request req, String clienteId, String fechamentoId) async {
    final rows = db.raw.select(
      'SELECT * FROM cliente_fechamentos WHERE id = ? AND cliente_id = ?',
      [fechamentoId, clienteId],
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

    // Validar que a nova data é posterior à atual
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

// ── Helpers ────────────────────────────────────────────────────────────────

/// Cria o próximo ciclo de fechamento para um cliente
void criarProximoCiclo(Db db, Cliente cliente, DateTime dataBase) {
  final uuid = const Uuid();

  // Determinar próximo número
  final maxNum = db.raw.select(
    'SELECT MAX(numero) as n FROM cliente_fechamentos WHERE cliente_id = ?',
    [cliente.id],
  ).first;
  final proxNum = ((maxNum['n'] as int?) ?? 0) + 1;

  final nowIso = DateTime.now().toIso8601String();
  final dataAbertura = _formatarData(dataBase);
  final dataFechamentoPrevista = _calcularProximaDataFechamento(
    cliente.fechamentoTipo!,
    cliente.fechamentoDia,
    cliente.fechamentoDataFixa,
    dataBase,
  );

  final novoId = uuid.v4();
  db.raw.execute('''
    INSERT INTO cliente_fechamentos (
      id, cliente_id, numero, data_abertura, data_fechamento_prevista,
      status, total_pedidos, valor_total, valor_pago,
      observacao, criado_em, atualizado_em
    ) VALUES (?,?,?,?,?, ?,0,0,0, ?,?,?)
  ''', [
    novoId,
    cliente.id,
    proxNum,
    dataAbertura,
    dataFechamentoPrevista,
    'aberto',
    null,
    nowIso,
    nowIso,
  ]);
}

/// Cria o primeiro ciclo de fechamento (ou retroativo) para um cliente
void criarFechamentoInicial(Db db, Cliente cliente, {bool retroativo = false}) {
  final uuid = const Uuid();
  final now = DateTime.now();
  final nowIso = now.toIso8601String();

  String dataAbertura;
  if (retroativo) {
    // Buscar data do pedido mais antigo do cliente
    final oldest = db.raw.select(
      'SELECT MIN(criado_em) as d FROM pedidos WHERE cliente_id = ?',
      [cliente.id],
    ).first;
    final oldestDate = oldest['d'] as String?;
    if (oldestDate != null) {
      dataAbertura = oldestDate.substring(0, 10);
    } else {
      dataAbertura = _formatarData(now);
    }
  } else {
    dataAbertura = _formatarData(now);
  }

  final dataFechamentoPrevista = _calcularProximaDataFechamento(
    cliente.fechamentoTipo!,
    cliente.fechamentoDia,
    cliente.fechamentoDataFixa,
    now,
  );

  final novoId = uuid.v4();
  final numero = 1;

  db.raw.execute('''
    INSERT INTO cliente_fechamentos (
      id, cliente_id, numero, data_abertura, data_fechamento_prevista,
      status, total_pedidos, valor_total, valor_pago,
      observacao, criado_em, atualizado_em
    ) VALUES (?,?,?,?,?, ?,0,0,0, ?,?,?)
  ''', [
    novoId,
    cliente.id,
    numero,
    dataAbertura,
    dataFechamentoPrevista,
    'aberto',
    null,
    nowIso,
    nowIso,
  ]);

  // Se retroativo, associar pedidos órfãos ao novo ciclo
  if (retroativo) {
    _associarPedidosOrfaos(db, cliente.id, novoId);
  }
}

/// Associa pedidos sem fechamento_id de um cliente a um ciclo
void _associarPedidosOrfaos(Db db, String clienteId, String fechamentoId) {
  db.raw.execute(
    'UPDATE pedidos SET fechamento_id = ? WHERE cliente_id = ? AND fechamento_id IS NULL',
    [fechamentoId, clienteId],
  );
  _recalcularAgregados(db, fechamentoId);
}

/// Recalcula total_pedidos, valor_total e valor_pago de um fechamento
void _recalcularAgregados(Db db, String fechamentoId) {
  final agg = db.raw.select(
    'SELECT COUNT(*) as total, COALESCE(SUM(valor), 0) as vt, COALESCE(SUM(valor_pago), 0) as vp '
    'FROM pedidos WHERE fechamento_id = ?',
    [fechamentoId],
  ).first;
  final nowIso = DateTime.now().toIso8601String();

  db.raw.execute('''
    UPDATE cliente_fechamentos
    SET total_pedidos = ?,
        valor_total = ?,
        valor_pago = ?,
        atualizado_em = ?
    WHERE id = ?
  ''', [
    agg['total'] as int,
    (agg['vt'] as num).toDouble(),
    (agg['vp'] as num).toDouble(),
    nowIso,
    fechamentoId,
  ]);
}

/// Calcula a próxima data de fechamento com base no tipo e configuração
String _calcularProximaDataFechamento(
  String tipo,
  int? dia,
  String? dataFixa,
  DateTime referencia,
) {
  DateTime proxima;

  switch (tipo) {
    case 'semanal':
      // dia: 1=segunda ... 7=domingo
      final alvo = dia ?? 5; // default sexta
      final diaAtual = referencia.weekday; // 1=seg ... 7=dom
      if (diaAtual < alvo) {
        proxima = referencia.add(Duration(days: alvo - diaAtual));
      } else if (diaAtual == alvo) {
        // Mesmo dia — próximo é daqui a 7 dias
        proxima = referencia.add(const Duration(days: 7));
      } else {
        proxima = referencia.add(Duration(days: 7 - diaAtual + alvo));
      }
      break;

    case 'quinzenal':
      // Fecha nos dias 15 e último dia do mês
      final diaAtualM = referencia.day;
      if (diaAtualM < 15) {
        proxima = DateTime(referencia.year, referencia.month, 15);
      } else {
        // Próximo: último dia do mês
        final ultimoDiaMes = DateTime(referencia.year, referencia.month + 1, 0).day;
        if (diaAtualM < ultimoDiaMes) {
          proxima = DateTime(referencia.year, referencia.month, ultimoDiaMes);
        } else {
          // Já passou do último dia, próximo ciclo: dia 15 do mês seguinte
          proxima = DateTime(referencia.year, referencia.month + 1, 15);
        }
      }
      break;

    case 'mensal':
      final diaMensal = dia ?? 1;
      final diaAtualM = referencia.day;
      if (diaAtualM < diaMensal) {
        proxima = DateTime(referencia.year, referencia.month, diaMensal);
      } else {
        proxima = DateTime(referencia.year, referencia.month + 1, diaMensal);
      }
      break;

    case 'data_fixa':
      if (dataFixa != null) {
        proxima = DateTime.parse(dataFixa);
      } else {
        proxima = referencia.add(const Duration(days: 30));
      }
      break;

    default:
      proxima = referencia.add(const Duration(days: 30));
  }

  return _formatarData(proxima);
}

/// Formata DateTime para YYYY-MM-DD
String _formatarData(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}