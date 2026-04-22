class Pedido {
  final String id;
  final int lote;
  final String? clienteId;
  final String clienteNome;
  final String? clienteTelefone;
  final String? clienteEmail;
  final String descricao;
  final String? peca;
  final String? tecnica;
  final int? quantidade;
  final double valor;

  final String? corPeca;
  final String? tamanhoPeca;
  final String? tecido;

  final int? arteCores;
  final String? arteTamanhoCm;
  final String? artePosicao;
  final String? arteObservacao;

  final DateTime? dataChegada;
  final DateTime? dataProducao;
  final int? prazoDias;
  final bool agendamentoFixo;

  final String? formaEntrega;
  final String? enderecoEntrega;
  final DateTime? dataEntregaCombinada;
  final DateTime? entregueEm;
  final String? entreguePor;

  final String? regiao;
  final String? tipoPeca;

  final String? formaPagamento;
  final double valorPago;
  final double sinalPago;
  final String statusPagamento;

  final String status;
  final bool urgente;
  final String? observacao;
  final String? fechamentoId;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  Pedido({
    required this.id,
    required this.lote,
    this.clienteId,
    required this.clienteNome,
    this.clienteTelefone,
    this.clienteEmail,
    required this.descricao,
    this.peca,
    this.tecnica,
    this.quantidade,
    required this.valor,
    this.corPeca,
    this.tamanhoPeca,
    this.tecido,
    this.arteCores,
    this.arteTamanhoCm,
    this.artePosicao,
    this.arteObservacao,
    this.dataChegada,
    this.dataProducao,
    this.prazoDias,
    this.agendamentoFixo = false,
    this.formaEntrega,
    this.enderecoEntrega,
    this.dataEntregaCombinada,
    this.entregueEm,
    this.entreguePor,
    this.regiao,
    this.tipoPeca,
    this.formaPagamento,
    this.valorPago = 0,
    this.sinalPago = 0,
    this.statusPagamento = 'devendo',
    this.status = 'pendente',
    this.urgente = false,
    this.observacao,
    this.fechamentoId,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  factory Pedido.fromJson(Map<String, dynamic> j) => Pedido(
        id: j['id'] as String,
        lote: j['lote'] as int,
        clienteId: j['cliente_id'] as String?,
        clienteNome: j['cliente_nome'] as String,
        clienteTelefone: j['cliente_telefone'] as String?,
        clienteEmail: j['cliente_email'] as String?,
        descricao: j['descricao'] as String,
        peca: j['peca'] as String?,
        tecnica: j['tecnica'] as String?,
        quantidade: j['quantidade'] as int?,
        valor: (j['valor'] as num).toDouble(),
        corPeca: j['cor_peca'] as String?,
        tamanhoPeca: j['tamanho_peca'] as String?,
        tecido: j['tecido'] as String?,
        arteCores: j['arte_cores'] as int?,
        arteTamanhoCm: j['arte_tamanho_cm'] as String?,
        artePosicao: j['arte_posicao'] as String?,
        arteObservacao: j['arte_observacao'] as String?,
        dataChegada: _parseDate(j['data_chegada']),
        dataProducao: _parseDate(j['data_producao']),
        prazoDias: j['prazo_dias'] as int?,
        agendamentoFixo: j['agendamento_fixo'] as bool? ?? false,
        formaEntrega: j['forma_entrega'] as String?,
        enderecoEntrega: j['endereco_entrega'] as String?,
        dataEntregaCombinada: _parseDate(j['data_entrega_combinada']),
        entregueEm: _parseDate(j['entregue_em']),
        entreguePor: j['entregue_por'] as String?,
        regiao: j['regiao'] as String?,
        tipoPeca: j['tipo_peca'] as String?,
        formaPagamento: j['forma_pagamento'] as String?,
        valorPago: ((j['valor_pago'] as num?) ?? 0).toDouble(),
        sinalPago: ((j['sinal_pago'] as num?) ?? 0).toDouble(),
        statusPagamento: (j['status_pagamento'] as String?) ?? 'devendo',
        status: j['status'] as String,
        urgente: j['urgente'] as bool? ?? false,
        observacao: j['observacao'] as String?,
        fechamentoId: j['fechamento_id'] as String?,
        criadoEm: DateTime.parse(j['criado_em'] as String),
        atualizadoEm: DateTime.parse(j['atualizado_em'] as String),
      );

  String get loteFormatado => 'LOTE${lote.toString().padLeft(4, '0')}';

  double get valorRestante => (valor - valorPago).clamp(0, double.infinity).toDouble();

  bool get pago => statusPagamento == 'pago';
  bool get parcial => statusPagamento == 'parcial';
  bool get devendo => statusPagamento == 'devendo';
  bool get entregue => status == 'entregue' || entregueEm != null;
}
