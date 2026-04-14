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
  final double faturamentoMes;
  final double aReceber;
  final List<Pedido> emProducaoHoje;
  final List<Pedido> prazosVencendo;
  final List<Pedido> ultimosMovimentos;
  final List<DiaOcupacao> ocupacaoSemana;
  final Map<String, int> porStatus;

  DashboardStats({
    required this.faturamentoMes,
    required this.aReceber,
    required this.emProducaoHoje,
    required this.prazosVencendo,
    required this.ultimosMovimentos,
    required this.ocupacaoSemana,
    required this.porStatus,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        faturamentoMes: (j['faturamento_mes'] as num).toDouble(),
        aReceber: (j['a_receber'] as num).toDouble(),
        emProducaoHoje: (j['em_producao_hoje'] as List)
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
        prazosVencendo: (j['prazos_vencendo'] as List)
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
        ultimosMovimentos: (j['ultimos_movimentos'] as List)
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
        ocupacaoSemana: (j['ocupacao_semana'] as List)
            .map((d) => DiaOcupacao.fromJson(d as Map<String, dynamic>))
            .toList(),
        porStatus: (j['por_status'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );
}
