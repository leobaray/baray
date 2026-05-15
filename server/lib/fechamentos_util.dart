import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models/cliente.dart';

const _uuid = Uuid();

/// Cria o próximo ciclo de fechamento para um cliente.
void criarProximoCiclo(Db db, Cliente cliente, DateTime dataBase) {
  final maxNum = db.raw.select(
    'SELECT MAX(numero) AS n FROM cliente_fechamentos WHERE cliente_id = ?',
    [cliente.id],
  ).first;
  final proxNum = ((maxNum['n'] as int?) ?? 0) + 1;

  final nowIso = DateTime.now().toUtc().toIso8601String();
  final dataAbertura = _formatarData(dataBase);
  final dataFechamentoPrevista = calcularProximaDataFechamento(
    cliente.fechamentoTipo!,
    cliente.fechamentoDia,
    dataBase,
  );

  db.raw.execute('''
    INSERT INTO cliente_fechamentos (
      id, cliente_id, numero, data_abertura, data_fechamento_prevista,
      status, total_pedidos, valor_total, valor_pago,
      observacao, criado_em, atualizado_em
    ) VALUES (?,?,?,?,?, ?,0,0,0, ?,?,?)
  ''', [
    _uuid.v4(),
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

/// Cria o primeiro ciclo de fechamento (ou retroativo) para um cliente.
void criarFechamentoInicial(Db db, Cliente cliente, {bool retroativo = false}) {
  final now = DateTime.now();
  final nowIso = now.toUtc().toIso8601String();

  String dataAbertura;
  if (retroativo) {
    final oldest = db.raw.select(
      'SELECT MIN(criado_em) AS d FROM pedidos WHERE cliente_id = ?',
      [cliente.id],
    ).first;
    final oldestDate = oldest['d'] as String?;
    dataAbertura = oldestDate != null && oldestDate.length >= 10
        ? oldestDate.substring(0, 10)
        : _formatarData(now);
  } else {
    dataAbertura = _formatarData(now);
  }

  final dataFechamentoPrevista = calcularProximaDataFechamento(
    cliente.fechamentoTipo!,
    cliente.fechamentoDia,
    now,
  );

  final novoId = _uuid.v4();
  db.raw.execute('''
    INSERT INTO cliente_fechamentos (
      id, cliente_id, numero, data_abertura, data_fechamento_prevista,
      status, total_pedidos, valor_total, valor_pago,
      observacao, criado_em, atualizado_em
    ) VALUES (?,?,?,?,?, ?,0,0,0, ?,?,?)
  ''', [
    novoId,
    cliente.id,
    1,
    dataAbertura,
    dataFechamentoPrevista,
    'aberto',
    null,
    nowIso,
    nowIso,
  ]);

  if (retroativo) {
    _associarPedidosOrfaos(db, cliente.id, novoId);
  }
}

void _associarPedidosOrfaos(Db db, String clienteId, String fechamentoId) {
  db.raw.execute(
    'UPDATE pedidos SET fechamento_id = ? WHERE cliente_id = ? AND fechamento_id IS NULL',
    [fechamentoId, clienteId],
  );
  recalcularAgregadosFechamento(db, fechamentoId);
}

/// Recalcula `total_pedidos`, `valor_total` e `valor_pago` de um fechamento.
void recalcularAgregadosFechamento(Db db, String fechamentoId) {
  final agg = db.raw.select(
    'SELECT COUNT(*) AS total, COALESCE(SUM(valor), 0) AS vt, COALESCE(SUM(valor_pago), 0) AS vp '
    'FROM pedidos WHERE fechamento_id = ?',
    [fechamentoId],
  ).first;
  final nowIso = DateTime.now().toUtc().toIso8601String();
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

/// Calcula a próxima data de fechamento com base no tipo e configuração.
///
/// `data_fixa` foi unificada com `mensal` na migration 007 — não é mais
/// tratada aqui (clientes legados foram convertidos pra 'mensal').
String calcularProximaDataFechamento(String tipo, int? dia, DateTime referencia) {
  final DateTime proxima;

  switch (tipo) {
    case 'semanal':
      final alvo = dia ?? 5;
      final diaAtual = referencia.weekday;
      if (diaAtual < alvo) {
        proxima = referencia.add(Duration(days: alvo - diaAtual));
      } else if (diaAtual == alvo) {
        proxima = referencia.add(const Duration(days: 7));
      } else {
        proxima = referencia.add(Duration(days: 7 - diaAtual + alvo));
      }
      break;

    case 'quinzenal':
      final diaAtualM = referencia.day;
      if (diaAtualM < 15) {
        proxima = DateTime(referencia.year, referencia.month, 15);
      } else {
        final ultimoDiaMes = DateTime(referencia.year, referencia.month + 1, 0).day;
        if (diaAtualM < ultimoDiaMes) {
          proxima = DateTime(referencia.year, referencia.month, ultimoDiaMes);
        } else {
          proxima = DateTime(referencia.year, referencia.month + 1, 15);
        }
      }
      break;

    case 'mensal':
    case 'data_fixa': // legado: mesma semântica de mensal
      final diaMensal = dia ?? 1;
      final diaAtualM = referencia.day;
      final int anoAlvo;
      final int mesAlvo;
      if (diaAtualM < diaMensal) {
        anoAlvo = referencia.year;
        mesAlvo = referencia.month;
      } else {
        anoAlvo = referencia.month == 12 ? referencia.year + 1 : referencia.year;
        mesAlvo = referencia.month == 12 ? 1 : referencia.month + 1;
      }
      final ultimoDiaMes = DateTime(anoAlvo, mesAlvo + 1, 0).day;
      final diaFinal = diaMensal > ultimoDiaMes ? ultimoDiaMes : diaMensal;
      proxima = DateTime(anoAlvo, mesAlvo, diaFinal);
      break;

    default:
      proxima = referencia.add(const Duration(days: 30));
  }

  return _formatarData(proxima);
}

String _formatarData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
