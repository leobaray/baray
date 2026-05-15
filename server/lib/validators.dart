/// Validações para payloads de POST/PUT.
///
/// Pequenas funções determinísticas que retornam a primeira mensagem de erro
/// encontrada (ou `null` se válido). Uso típico nas rotas:
///
/// ```dart
/// final erro = validarPedido(body, criar: true);
/// if (erro != null) return json({'error': erro}, status: 400);
/// ```
library;

const Set<String> statusValidos = {
  'pendente',
  'agendado',
  'producao',
  'concluido',
  'entregue',
};

const Set<String> statusPagamentoValidos = {'devendo', 'parcial', 'pago'};

const Set<String> formasPagamentoValidas = {
  'pix',
  'dinheiro',
  'cartao_credito',
  'cartao_debito',
  'transferencia',
  'boleto',
  'fiado',
};

const Set<String> regioesValidas = {'FRENTE/COSTAS', 'BOTTOM/NUCA'};

const Set<String> tiposPecaValidos = {
  'camiseta',
  'moletom',
  'moletom_aberto',
  'moletom_fechado',
  'bone',
  'sacola',
  'outro',
};

// Aceita tanto os substantivos enviados pela UI atual ('retirada','entrega')
// quanto os verbos legados ('retirar','entregar','correios') que podem existir
// em registros antigos no banco. Mantém backward-compat sem migração de dados.
const Set<String> formasEntregaValidas = {
  'retirada',
  'entrega',
  'retirar',
  'entregar',
  'correios',
};

const Set<String> fechamentoTiposValidos = {
  'semanal',
  'quinzenal',
  'mensal',
  'data_fixa',
};

/// Validação dos campos comuns a POST e PUT de pedidos. `criar=true` força
/// presença dos campos obrigatórios; `criar=false` aceita ausência (PUT é
/// parcial) mas valida os campos que estão presentes.
String? validarPedido(Map<String, dynamic> body, {required bool criar}) {
  if (criar) {
    final nome = (body['cliente_nome'] as String?)?.trim();
    if (nome == null || nome.isEmpty) return 'cliente_nome é obrigatório';
    final descricao = (body['descricao'] as String?)?.trim();
    if (descricao == null || descricao.isEmpty) return 'descricao é obrigatória';
    if (body['valor'] == null) return 'valor é obrigatório';
  }

  if (body.containsKey('valor')) {
    final v = (body['valor'] as num?)?.toDouble();
    if (v == null || !v.isFinite || v <= 0) return 'valor deve ser maior que 0';
  }

  if (body.containsKey('quantidade')) {
    final q = body['quantidade'];
    if (q != null && (q is! int || q <= 0)) return 'quantidade deve ser inteiro positivo';
  }

  if (body.containsKey('arte_cores')) {
    final c = body['arte_cores'];
    if (c != null && (c is! int || c < 1 || c > 10)) {
      return 'arte_cores deve estar entre 1 e 10';
    }
  }

  if (body.containsKey('valor_pago')) {
    // Reservado pra cache derivado — não aceitar edição direta (C-03).
    return 'valor_pago não pode ser editado diretamente — use /pagamentos';
  }

  if (body.containsKey('sinal_pago')) {
    final s = (body['sinal_pago'] as num?)?.toDouble();
    if (s != null && s < 0) return 'sinal_pago não pode ser negativo';
  }

  final enumErro = _validarEnum(body, 'status', statusValidos) ??
      _validarEnum(body, 'status_pagamento', statusPagamentoValidos) ??
      _validarEnum(body, 'forma_pagamento', formasPagamentoValidas) ??
      _validarEnum(body, 'regiao', regioesValidas) ??
      _validarEnum(body, 'tipo_peca', tiposPecaValidos) ??
      _validarEnum(body, 'forma_entrega', formasEntregaValidas);
  if (enumErro != null) return enumErro;

  return null;
}

/// Validações de cliente, especialmente das colunas de fechamento.
String? validarCliente(Map<String, dynamic> body, {required bool criar}) {
  if (criar) {
    final nome = (body['nome'] as String?)?.trim();
    if (nome == null || nome.isEmpty) return 'nome é obrigatório';
  }

  if (body.containsKey('fechamento_tipo') && body['fechamento_tipo'] != null) {
    final tipo = body['fechamento_tipo'];
    if (tipo is! String || !fechamentoTiposValidos.contains(tipo)) {
      return 'fechamento_tipo inválido (use: ${fechamentoTiposValidos.join(", ")})';
    }
  }

  if (body.containsKey('fechamento_dia') && body['fechamento_dia'] != null) {
    final d = body['fechamento_dia'];
    if (d is! int) return 'fechamento_dia deve ser inteiro';
    final tipo = body['fechamento_tipo'] as String?;
    if (tipo == 'semanal' && (d < 1 || d > 7)) return 'fechamento_dia (semanal) deve estar entre 1 e 7';
    if (tipo != 'semanal' && (d < 1 || d > 31)) return 'fechamento_dia deve estar entre 1 e 31';
  }

  return null;
}

String? _validarEnum(Map<String, dynamic> body, String campo, Set<String> validos) {
  if (!body.containsKey(campo) || body[campo] == null) return null;
  final v = body[campo];
  if (v is! String || !validos.contains(v)) {
    return '$campo inválido (use: ${validos.join(", ")})';
  }
  return null;
}
