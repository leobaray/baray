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

  final String? dataChegada;
  final String? dataProducao;
  final int? prazoDias;
  final bool agendamentoFixo;

  final String? formaEntrega;
  final String? enderecoEntrega;
  final String? dataEntregaCombinada;
  final String? entregueEm;
  final String? entreguePor;

  final String? formaPagamento;
  final double valorPago;
  final double sinalPago;
  final String statusPagamento;

  final String status;
  final bool urgente;
  final String? observacao;
  final String? fechamentoId;
  final String criadoEm;
  final String atualizadoEm;

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

  factory Pedido.fromRow(Map<String, dynamic> r) => Pedido(
        id: r['id'] as String,
        lote: r['lote'] as int,
        clienteId: r['cliente_id'] as String?,
        clienteNome: r['cliente_nome'] as String,
        clienteTelefone: r['cliente_telefone'] as String?,
        clienteEmail: r['cliente_email'] as String?,
        descricao: r['descricao'] as String,
        peca: r['peca'] as String?,
        tecnica: r['tecnica'] as String?,
        quantidade: r['quantidade'] as int?,
        valor: (r['valor'] as num).toDouble(),
        corPeca: r['cor_peca'] as String?,
        tamanhoPeca: r['tamanho_peca'] as String?,
        tecido: r['tecido'] as String?,
        arteCores: r['arte_cores'] as int?,
        arteTamanhoCm: r['arte_tamanho_cm'] as String?,
        artePosicao: r['arte_posicao'] as String?,
        arteObservacao: r['arte_observacao'] as String?,
        dataChegada: r['data_chegada'] as String?,
        dataProducao: r['data_producao'] as String?,
        prazoDias: r['prazo_dias'] as int?,
        agendamentoFixo: (r['agendamento_fixo'] as int?) == 1,
        formaEntrega: r['forma_entrega'] as String?,
        enderecoEntrega: r['endereco_entrega'] as String?,
        dataEntregaCombinada: r['data_entrega_combinada'] as String?,
        entregueEm: r['entregue_em'] as String?,
        entreguePor: r['entregue_por'] as String?,
        formaPagamento: r['forma_pagamento'] as String?,
        valorPago: ((r['valor_pago'] as num?) ?? 0).toDouble(),
        sinalPago: ((r['sinal_pago'] as num?) ?? 0).toDouble(),
        statusPagamento: (r['status_pagamento'] as String?) ?? 'devendo',
        status: r['status'] as String,
        urgente: (r['urgente'] as int) == 1,
        observacao: r['observacao'] as String?,
        fechamentoId: r['fechamento_id'] as String?,
        criadoEm: r['criado_em'] as String,
        atualizadoEm: r['atualizado_em'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'lote': lote,
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'cliente_telefone': clienteTelefone,
        'cliente_email': clienteEmail,
        'descricao': descricao,
        'peca': peca,
        'tecnica': tecnica,
        'quantidade': quantidade,
        'valor': valor,
        'cor_peca': corPeca,
        'tamanho_peca': tamanhoPeca,
        'tecido': tecido,
        'arte_cores': arteCores,
        'arte_tamanho_cm': arteTamanhoCm,
        'arte_posicao': artePosicao,
        'arte_observacao': arteObservacao,
        'data_chegada': dataChegada,
        'data_producao': dataProducao,
        'prazo_dias': prazoDias,
        'agendamento_fixo': agendamentoFixo,
        'forma_entrega': formaEntrega,
        'endereco_entrega': enderecoEntrega,
        'data_entrega_combinada': dataEntregaCombinada,
        'entregue_em': entregueEm,
        'entregue_por': entreguePor,
        'forma_pagamento': formaPagamento,
        'valor_pago': valorPago,
        'sinal_pago': sinalPago,
        'status_pagamento': statusPagamento,
        'status': status,
        'urgente': urgente,
        'observacao': observacao,
        'fechamento_id': fechamentoId,
        'criado_em': criadoEm,
        'atualizado_em': atualizadoEm,
      };
}
