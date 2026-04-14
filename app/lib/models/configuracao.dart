class Configuracao {
  final String chave;
  final String valor;
  final String tipo; // 'string' | 'number' | 'bool'
  final String? descricao;

  Configuracao({
    required this.chave,
    required this.valor,
    required this.tipo,
    this.descricao,
  });

  factory Configuracao.fromJson(Map<String, dynamic> j) => Configuracao(
        chave: j['chave'] as String,
        valor: j['valor'] as String,
        tipo: j['tipo'] as String,
        descricao: j['descricao'] as String?,
      );

  num get asNumber => num.tryParse(valor) ?? 0;
  bool get asBool => valor == 'true' || valor == '1';
}
