import 'package:uuid/uuid.dart';

import 'db.dart';

/// Lançada quando o agendador não consegue alocar o pedido por motivo de
/// regra de negócio (capacidade insuficiente, range de >1 ano). Handlers das
/// rotas convertem isso em HTTP 400.
class AgendadorCapacidadeException implements Exception {
  final String message;
  AgendadorCapacidadeException(this.message);
  @override
  String toString() => message;
}

/// Agendador automático — substituto do Módulo6 da planilha.
///
/// Escolhe a data (ou sequência de datas) em que um pedido entra em produção,
/// respeitando o limite diário em R\$ e pulando fim de semana conforme config.
class Agendador {
  final Db db;
  Agendador(this.db);

  DateTime agendar({
    required String pedidoId,
    required double valor,
    DateTime? dataChegada,
    bool ignorarFixacao = false,
  }) {
    if (valor <= 0.0001) {
      throw AgendadorCapacidadeException(
        'pedido sem valor positivo — não pode ser agendado',
      );
    }

    // A-03: pedido fixado mantém a distribuição atual; só recalcula quando
    // chamado explicitamente com `ignorarFixacao: true`.
    if (!ignorarFixacao) {
      final fix = db.raw.select(
        'SELECT agendamento_fixo, data_producao FROM pedidos WHERE id = ?',
        [pedidoId],
      );
      if (fix.isNotEmpty &&
          (fix.first['agendamento_fixo'] as int?) == 1 &&
          fix.first['data_producao'] != null) {
        final dataProd = fix.first['data_producao'] as String;
        return DateTime.parse(dataProd.length >= 10 ? dataProd.substring(0, 10) : dataProd);
      }
    }

    final limite = db.configNumber('limite_diario', 1200);
    final sabado = db.configBool('producao_sabado', false);
    final domingo = db.configBool('producao_domingo', false);

    db.raw.execute('DELETE FROM pedido_distribuicao WHERE pedido_id = ?', [pedidoId]);

    var cursor = _diaInicio(dataChegada ?? DateTime.now());
    cursor = _proximoDiaUtil(cursor, sabado: sabado, domingo: domingo);

    final distribuicao = <MapEntry<DateTime, double>>[];
    var restante = valor;

    final jaAgendado = _ocupacaoPorDia(pedidoId);

    var guard = 0;
    while (restante > 0.0001) {
      if (guard++ > 365) {
        throw AgendadorCapacidadeException(
          'capacidade insuficiente: pedido excede 1 ano útil — ajuste limite diário em Configurações',
        );
      }
      final chave = _chaveDia(cursor);
      final ocupado = jaAgendado[chave] ?? 0;
      final livre = (limite - ocupado).clamp(0, double.infinity).toDouble();
      if (livre <= 0.0001) {
        cursor = _proximoDiaUtil(cursor.add(const Duration(days: 1)), sabado: sabado, domingo: domingo);
        continue;
      }
      final parcela = restante <= livre ? restante : livre;
      distribuicao.add(MapEntry(cursor, parcela));
      restante -= parcela;
      cursor = _proximoDiaUtil(cursor.add(const Duration(days: 1)), sabado: sabado, domingo: domingo);
    }

    const uuid = Uuid();
    final stmt = db.raw.prepare(
      'INSERT INTO pedido_distribuicao (id, pedido_id, data, parcela_valor) VALUES (?,?,?,?)',
    );
    for (final d in distribuicao) {
      stmt.execute([uuid.v4(), pedidoId, _chaveDia(d.key), d.value]);
    }
    stmt.close();

    return distribuicao.first.key;
  }

  // M-07: full-scan intencional. Agendamento precisa do estado de ocupação
  // global por dia para alocar parcelas — qualquer LIMIT distorceria o
  // resultado. Mitigação: criar índice em `pedido_distribuicao.data` e
  // agregar via SQL se o volume crescer (follow-up).
  Map<String, double> _ocupacaoPorDia(String? excluirPedidoId) {
    final resultado = <String, double>{};

    final rows = db.raw.select(
      'SELECT pd.data, pd.parcela_valor FROM pedido_distribuicao pd '
      'WHERE pd.pedido_id != ? OR ? IS NULL',
      [excluirPedidoId ?? '', excluirPedidoId],
    );
    for (final r in rows) {
      final data = r['data'] as String;
      final v = (r['parcela_valor'] as num).toDouble();
      resultado[data] = (resultado[data] ?? 0) + v;
    }

    final pedidosSemDistribuicao = db.raw.select('''
      SELECT p.id, p.valor, p.data_producao FROM pedidos p
      WHERE p.data_producao IS NOT NULL
        AND p.id != ?
        AND NOT EXISTS (SELECT 1 FROM pedido_distribuicao d WHERE d.pedido_id = p.id)
    ''', [excluirPedidoId ?? '']);
    for (final r in pedidosSemDistribuicao) {
      final data = (r['data_producao'] as String).substring(0, 10);
      final v = (r['valor'] as num).toDouble();
      resultado[data] = (resultado[data] ?? 0) + v;
    }

    return resultado;
  }

  int calcularPrazoDias(DateTime chegada, DateTime producao) {
    final sabado = db.configBool('producao_sabado', false);
    final domingo = db.configBool('producao_domingo', false);
    var dias = 0;
    var cursor = _diaInicio(chegada);
    final alvo = _diaInicio(producao);
    while (cursor.isBefore(alvo)) {
      cursor = cursor.add(const Duration(days: 1));
      final wd = cursor.weekday;
      if (wd == DateTime.saturday && !sabado) continue;
      if (wd == DateTime.sunday && !domingo) continue;
      dias++;
    }
    return dias;
  }

  List<Map<String, Object>> proximosDias(int n) {
    final sabado = db.configBool('producao_sabado', false);
    final domingo = db.configBool('producao_domingo', false);
    final limite = db.configNumber('limite_diario', 1200);
    final ocupacao = _ocupacaoPorDia(null);

    final dias = <Map<String, Object>>[];
    var cursor = _diaInicio(DateTime.now());
    while (dias.length < n) {
      cursor = _proximoDiaUtil(cursor, sabado: sabado, domingo: domingo);
      final chave = _chaveDia(cursor);
      dias.add({
        'data': chave,
        'ocupado': ocupacao[chave] ?? 0.0,
        'limite': limite,
      });
      cursor = cursor.add(const Duration(days: 1));
    }
    return dias;
  }

  static DateTime _diaInicio(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _proximoDiaUtil(DateTime d, {required bool sabado, required bool domingo}) {
    var cur = _diaInicio(d);
    while (true) {
      if (cur.weekday == DateTime.saturday && !sabado) {
        cur = cur.add(const Duration(days: 1));
        continue;
      }
      if (cur.weekday == DateTime.sunday && !domingo) {
        cur = cur.add(const Duration(days: 1));
        continue;
      }
      return cur;
    }
  }

  static String _chaveDia(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
