class Pagamento {
  final String id;
  final String pedidoId;
  final double valor;
  final String? forma;
  final DateTime quando;
  final String? observacao;

  Pagamento({
    required this.id,
    required this.pedidoId,
    required this.valor,
    this.forma,
    required this.quando,
    this.observacao,
  });

  factory Pagamento.fromJson(Map<String, dynamic> j) => Pagamento(
        id: j['id'] as String,
        pedidoId: j['pedido_id'] as String,
        valor: (j['valor'] as num).toDouble(),
        forma: j['forma'] as String?,
        quando: DateTime.parse(j['quando'] as String),
        observacao: j['observacao'] as String?,
      );
}
