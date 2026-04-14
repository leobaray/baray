class Cliente {
  final String id;
  final String nome;
  final String? telefone;
  final String? email;
  final String? endereco;
  final String? observacao;
  final String? fechamentoTipo;
  final int? fechamentoDia;
  final String? fechamentoDataFixa;
  final bool fechamentoAtivo;
  final String criadoEm;
  final String atualizadoEm;

  Cliente({
    required this.id,
    required this.nome,
    this.telefone,
    this.email,
    this.endereco,
    this.observacao,
    this.fechamentoTipo,
    this.fechamentoDia,
    this.fechamentoDataFixa,
    this.fechamentoAtivo = false,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory Cliente.fromRow(Map<String, dynamic> r) => Cliente(
        id: r['id'] as String,
        nome: r['nome'] as String,
        telefone: r['telefone'] as String?,
        email: r['email'] as String?,
        endereco: r['endereco'] as String?,
        observacao: r['observacao'] as String?,
        fechamentoTipo: r['fechamento_tipo'] as String?,
        fechamentoDia: r['fechamento_dia'] as int?,
        fechamentoDataFixa: r['fechamento_data_fixa'] as String?,
        fechamentoAtivo: (r['fechamento_ativo'] as int?) == 1,
        criadoEm: r['criado_em'] as String,
        atualizadoEm: (r['atualizado_em'] as String?) ?? r['criado_em'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'endereco': endereco,
        'observacao': observacao,
        'fechamento_tipo': fechamentoTipo,
        'fechamento_dia': fechamentoDia,
        'fechamento_data_fixa': fechamentoDataFixa,
        'fechamento_ativo': fechamentoAtivo ? 1 : 0,
        'criado_em': criadoEm,
        'atualizado_em': atualizadoEm,
      };
}
