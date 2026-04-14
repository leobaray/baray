class ItemPreco {
  final String id;
  final String tecnica;
  final String regiao;
  final String faixaQtd;
  final double primeiraCor;
  final double demaisCores;

  ItemPreco({
    required this.id,
    required this.tecnica,
    required this.regiao,
    required this.faixaQtd,
    required this.primeiraCor,
    required this.demaisCores,
  });

  factory ItemPreco.fromRow(Map<String, dynamic> r) => ItemPreco(
        id: r['id'] as String,
        tecnica: r['tecnica'] as String,
        regiao: r['regiao'] as String,
        faixaQtd: r['faixa_qtd'] as String,
        primeiraCor: (r['primeira_cor'] as num).toDouble(),
        demaisCores: (r['demais_cores'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tecnica': tecnica,
        'regiao': regiao,
        'faixa_qtd': faixaQtd,
        'primeira_cor': primeiraCor,
        'demais_cores': demaisCores,
      };
}
