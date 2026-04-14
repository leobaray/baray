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

  factory ItemPreco.fromJson(Map<String, dynamic> j) => ItemPreco(
        id: j['id'] as String,
        tecnica: j['tecnica'] as String,
        regiao: j['regiao'] as String,
        faixaQtd: j['faixa_qtd'] as String,
        primeiraCor: (j['primeira_cor'] as num).toDouble(),
        demaisCores: (j['demais_cores'] as num).toDouble(),
      );
}

class OrcamentoResultado {
  final String tecnica;
  final String regiao;
  final String faixaQtd;
  final int quantidade;
  final int cores;
  final bool urgente;
  final String? tipoPeca;
  final double precoPorPeca;
  final double subtotal;
  final bool matrizCobrada;
  final double valorMatriz;
  final double total;

  OrcamentoResultado({
    required this.tecnica,
    required this.regiao,
    required this.faixaQtd,
    required this.quantidade,
    required this.cores,
    required this.urgente,
    this.tipoPeca,
    required this.precoPorPeca,
    required this.subtotal,
    required this.matrizCobrada,
    required this.valorMatriz,
    required this.total,
  });

  factory OrcamentoResultado.fromJson(Map<String, dynamic> j) => OrcamentoResultado(
        tecnica: j['tecnica'] as String,
        regiao: j['regiao'] as String,
        faixaQtd: j['faixa_qtd'] as String,
        quantidade: j['quantidade'] as int,
        cores: j['cores'] as int,
        urgente: j['urgente'] as bool,
        tipoPeca: j['tipo_peca'] as String?,
        precoPorPeca: (j['preco_por_peca'] as num).toDouble(),
        subtotal: (j['subtotal'] as num).toDouble(),
        matrizCobrada: j['matriz_cobrada'] as bool,
        valorMatriz: (j['valor_matriz'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}
