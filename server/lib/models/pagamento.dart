class Pagamento {
  final String id;
  final String pedidoId;
  final double valor;
  final String? forma;
  final String quando;
  final String? observacao;

  Pagamento({
    required this.id,
    required this.pedidoId,
    required this.valor,
    this.forma,
    required this.quando,
    this.observacao,
  });

  factory Pagamento.fromRow(Map<String, dynamic> r) => Pagamento(
        id: r['id'] as String,
        pedidoId: r['pedido_id'] as String,
        valor: (r['valor'] as num).toDouble(),
        forma: r['forma'] as String?,
        quando: r['quando'] as String,
        observacao: r['observacao'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pedido_id': pedidoId,
        'valor': valor,
        'forma': forma,
        'quando': quando,
        'observacao': observacao,
      };
}
