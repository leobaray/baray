class ClienteFechamento {
  final String id;
  final String clienteId;
  final int numero;
  final String dataAbertura;
  final String dataFechamentoPrevista;
  final String? dataFechamentoReal;
  final String status;
  final int totalPedidos;
  final double valorTotal;
  final double valorPago;
  final String? observacao;
  final String criadoEm;
  final String atualizadoEm;

  ClienteFechamento({
    required this.id,
    required this.clienteId,
    required this.numero,
    required this.dataAbertura,
    required this.dataFechamentoPrevista,
    this.dataFechamentoReal,
    required this.status,
    this.totalPedidos = 0,
    this.valorTotal = 0,
    this.valorPago = 0,
    this.observacao,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory ClienteFechamento.fromRow(Map<String, dynamic> r) => ClienteFechamento(
        id: r['id'] as String,
        clienteId: r['cliente_id'] as String,
        numero: r['numero'] as int,
        dataAbertura: r['data_abertura'] as String,
        dataFechamentoPrevista: r['data_fechamento_prevista'] as String,
        dataFechamentoReal: r['data_fechamento_real'] as String?,
        status: r['status'] as String,
        totalPedidos: (r['total_pedidos'] as int?) ?? 0,
        valorTotal: (r['valor_total'] as num?)?.toDouble() ?? 0,
        valorPago: (r['valor_pago'] as num?)?.toDouble() ?? 0,
        observacao: r['observacao'] as String?,
        criadoEm: r['criado_em'] as String,
        atualizadoEm: r['atualizado_em'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'numero': numero,
        'data_abertura': dataAbertura,
        'data_fechamento_prevista': dataFechamentoPrevista,
        'data_fechamento_real': dataFechamentoReal,
        'status': status,
        'total_pedidos': totalPedidos,
        'valor_total': valorTotal,
        'valor_pago': valorPago,
        'observacao': observacao,
        'criado_em': criadoEm,
        'atualizado_em': atualizadoEm,
      };
}