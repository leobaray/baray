import 'pedido.dart';

class DiaOcupacao {
  final DateTime data;
  final double ocupado;
  final double limite;

  DiaOcupacao({required this.data, required this.ocupado, required this.limite});

  factory DiaOcupacao.fromJson(Map<String, dynamic> j) => DiaOcupacao(
        data: DateTime.parse(j['data'] as String),
        ocupado: (j['ocupado'] as num).toDouble(),
        limite: (j['limite'] as num).toDouble(),
      );

  double get pct => limite <= 0 ? 0 : (ocupado / limite).clamp(0, 2).toDouble();
  bool get estourado => ocupado > limite;
}

class DashboardStats {
  final double vendasMes;
  final double recebidoMes;
  final int pedidosMes;
  final int concluidosMes;
  final double ticketMedio;
  final double aReceber;
  final List<Pedido> emProducaoHoje;
  final List<Pedido> urgentes;
  final List<Pedido> prazosVencendo;
  final List<DiaOcupacao> ocupacaoSemana;
  final String hoje;
  final String inicioMes;
  final String fimMes;

  DashboardStats({
    required this.vendasMes,
    required this.recebidoMes,
    required this.pedidosMes,
    required this.concluidosMes,
    required this.ticketMedio,
    required this.aReceber,
    required this.emProducaoHoje,
    required this.urgentes,
    required this.prazosVencendo,
    required this.ocupacaoSemana,
    required this.hoje,
    required this.inicioMes,
    required this.fimMes,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        vendasMes: (j['vendas_mes'] as num).toDouble(),
        recebidoMes: ((j['recebido_mes'] as num?) ?? 0).toDouble(),
        pedidosMes: (j['pedidos_mes'] as int?) ?? 0,
        concluidosMes: (j['concluidos_mes'] as int?) ?? 0,
        ticketMedio: ((j['ticket_medio'] as num?) ?? 0).toDouble(),
        aReceber: (j['a_receber'] as num).toDouble(),
        emProducaoHoje: (j['em_producao_hoje'] as List)
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
        urgentes: ((j['urgentes'] as List?) ?? const [])
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
        prazosVencendo: (j['prazos_vencendo'] as List)
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
        ocupacaoSemana: (j['ocupacao_semana'] as List)
            .map((d) => DiaOcupacao.fromJson(d as Map<String, dynamic>))
            .toList(),
        hoje: (j['hoje'] as String?) ?? '',
        inicioMes: (j['inicio_mes'] as String?) ?? '',
        fimMes: (j['fim_mes'] as String?) ?? '',
      );
}
