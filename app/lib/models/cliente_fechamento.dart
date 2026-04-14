class ClienteFechamento {
  final String id;
  final String clienteId;
  final int numero;
  final DateTime dataAbertura;
  final DateTime dataFechamentoPrevista;
  final DateTime? dataFechamentoReal;
  final String status;
  final int totalPedidos;
  final double valorTotal;
  final double valorPago;
  final String? observacao;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

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

  factory ClienteFechamento.fromJson(Map<String, dynamic> j) {
    return ClienteFechamento(
      id: j['id'] as String,
      clienteId: j['cliente_id'] as String,
      numero: j['numero'] as int,
      dataAbertura: DateTime.parse(j['data_abertura'] as String),
      dataFechamentoPrevista: DateTime.parse(j['data_fechamento_prevista'] as String),
      dataFechamentoReal: j['data_fechamento_real'] != null
          ? DateTime.parse(j['data_fechamento_real'] as String)
          : null,
      status: j['status'] as String,
      totalPedidos: (j['total_pedidos'] as int?) ?? 0,
      valorTotal: ((j['valor_total'] as num?) ?? 0).toDouble(),
      valorPago: ((j['valor_pago'] as num?) ?? 0).toDouble(),
      observacao: j['observacao'] as String?,
      criadoEm: DateTime.parse(j['criado_em'] as String),
      atualizadoEm: DateTime.parse(j['atualizado_em'] as String),
    );
  }

  double get valorPendente => (valorTotal - valorPago).clamp(0, double.infinity).toDouble();
  bool get aberto => status == 'aberto' || status == 'estendido';
  bool get fechado => status == 'fechado';

  String get statusLabel => switch (status) {
        'aberto' => 'Aberto',
        'estendido' => 'Estendido',
        'fechado' => 'Fechado',
        _ => status,
      };
}