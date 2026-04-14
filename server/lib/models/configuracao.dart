class Configuracao {
  final String chave;
  final String valor;
  final String tipo; // 'string' | 'number' | 'bool'
  final String? descricao;
  final String atualizadoEm;

  Configuracao({
    required this.chave,
    required this.valor,
    required this.tipo,
    this.descricao,
    required this.atualizadoEm,
  });

  factory Configuracao.fromRow(Map<String, dynamic> r) => Configuracao(
        chave: r['chave'] as String,
        valor: r['valor'] as String,
        tipo: r['tipo'] as String,
        descricao: r['descricao'] as String?,
        atualizadoEm: r['atualizado_em'] as String,
      );

  Map<String, dynamic> toJson() => {
        'chave': chave,
        'valor': valor,
        'tipo': tipo,
        'descricao': descricao,
        'atualizado_em': atualizadoEm,
      };
}
