import 'pedido.dart';
import 'cliente_fechamento.dart';

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
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  final int totalPedidos;
  final double totalGasto;
  final double valorDevendo;
  final List<Pedido>? pedidos;
  final ClienteFechamento? fechamentoAtual;

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
    this.totalPedidos = 0,
    this.totalGasto = 0,
    this.valorDevendo = 0,
    this.pedidos,
    this.fechamentoAtual,
  });

  factory Cliente.fromJson(Map<String, dynamic> j) {
    final pedidosJson = j['pedidos'] as List?;
    final fechamentoAtualJson = j['fechamento_atual'] as Map<String, dynamic>?;
    return Cliente(
      id: j['id'] as String,
      nome: j['nome'] as String,
      telefone: j['telefone'] as String?,
      email: j['email'] as String?,
      endereco: j['endereco'] as String?,
      observacao: j['observacao'] as String?,
      fechamentoTipo: j['fechamento_tipo'] as String?,
      fechamentoDia: j['fechamento_dia'] as int?,
      fechamentoDataFixa: j['fechamento_data_fixa'] as String?,
      fechamentoAtivo: (j['fechamento_ativo'] as int?) == 1,
      criadoEm: DateTime.parse(j['criado_em'] as String),
      atualizadoEm: DateTime.parse(j['atualizado_em'] as String),
      totalPedidos: (j['total_pedidos'] as int?) ?? 0,
      totalGasto: ((j['total_gasto'] as num?) ?? 0).toDouble(),
      valorDevendo: ((j['valor_devendo'] as num?) ?? 0).toDouble(),
      pedidos: pedidosJson?.map((p) => Pedido.fromJson(p as Map<String, dynamic>)).toList(),
      fechamentoAtual: fechamentoAtualJson != null
          ? ClienteFechamento.fromJson(fechamentoAtualJson)
          : null,
    );
  }

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1)).toUpperCase();
  }
}
