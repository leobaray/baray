import 'pedido.dart';

/// Representa a ocupação de um único dia útil da agenda.
/// `ocupado` vem da soma de `pedido_distribuicao` + pedidos sem distribuição,
/// portanto respeita pedidos grandes que se espalham por múltiplos dias.
class DiaAgenda {
  final DateTime data;
  final double ocupado;
  final double limite;
  final List<Pedido> pedidos;

  DiaAgenda({
    required this.data,
    required this.ocupado,
    required this.limite,
    required this.pedidos,
  });

  factory DiaAgenda.fromJson(Map<String, dynamic> j) => DiaAgenda(
        data: DateTime.parse(j['data'] as String),
        ocupado: (j['ocupado'] as num).toDouble(),
        limite: (j['limite'] as num).toDouble(),
        pedidos: ((j['pedidos'] as List?) ?? const [])
            .map((p) => Pedido.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  double get pct => limite <= 0 ? 0 : (ocupado / limite).clamp(0, 2).toDouble();
  bool get acima => ocupado > limite;
  bool get vazio => pedidos.isEmpty;
}

class AgendaOcupacao {
  final List<DiaAgenda> dias;
  final int semData;

  AgendaOcupacao({required this.dias, required this.semData});

  factory AgendaOcupacao.fromJson(Map<String, dynamic> j) => AgendaOcupacao(
        dias: (j['dias'] as List)
            .map((d) => DiaAgenda.fromJson(d as Map<String, dynamic>))
            .toList(),
        semData: (j['sem_data'] as int?) ?? 0,
      );
}
