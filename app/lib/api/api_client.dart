import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cliente.dart';
import '../models/cliente_fechamento.dart';
import '../models/configuracao.dart';
import '../models/dashboard.dart';
import '../models/orcamento.dart';
import '../models/pagamento.dart';
import '../models/pedido.dart';

const String defaultServerUrl = 'http://10.150.60.100:8080';
const String prefsKeyServerUrl = 'server_url';

class ApiClient {
  final Dio dio;
  String baseUrl;

  ApiClient(this.baseUrl)
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'content-type': 'application/json'},
        ));

  void updateBaseUrl(String url) {
    baseUrl = url;
    dio.options.baseUrl = url;
  }

  Future<bool> health() async {
    try {
      final r = await dio.get('/health');
      return r.statusCode == 200 && r.data is Map && r.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Pedidos ────────────────────────────────────────────────────────────
  Future<List<Pedido>> listarPedidos({
    String? status,
    String? statusPagamento,
    String? cliente,
    String? clienteId,
    String? busca,
    bool? urgente,
    String? de,
    String? ate,
    String? ordenar,
  }) async {
    final r = await dio.get('/pedidos', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (statusPagamento != null && statusPagamento.isNotEmpty) 'status_pagamento': statusPagamento,
      if (cliente != null && cliente.isNotEmpty) 'cliente': cliente,
      if (clienteId != null && clienteId.isNotEmpty) 'cliente_id': clienteId,
      if (busca != null && busca.isNotEmpty) 'busca': busca,
      if (urgente == true) 'urgente': 'true',
      if (de != null && de.isNotEmpty) 'de': de,
      if (ate != null && ate.isNotEmpty) 'ate': ate,
      if (ordenar != null && ordenar.isNotEmpty) 'ordenar': ordenar,
    });
    return (r.data as List).map((j) => Pedido.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Pedido> buscarPedido(String id) async {
    final r = await dio.get('/pedidos/$id');
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Pedido> criarPedido(Map<String, dynamic> body) async {
    final r = await dio.post('/pedidos', data: body);
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Pedido> atualizarPedido(String id, Map<String, dynamic> patch) async {
    final r = await dio.put('/pedidos/$id', data: patch);
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deletarPedido(String id) async {
    await dio.delete('/pedidos/$id');
  }

  Future<Pedido> agendarPedido(String id) async {
    final r = await dio.post('/pedidos/$id/agendar');
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Pedido> confirmarSaida(String id, {String? entreguePor}) async {
    final r = await dio.post(
      '/pedidos/$id/saida',
      data: {if (entreguePor != null) 'entregue_por': entreguePor},
    );
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Pedido> duplicarPedido(String id) async {
    final r = await dio.post('/pedidos/$id/duplicar');
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Clientes ───────────────────────────────────────────────────────────
  Future<List<Cliente>> listarClientes({String? busca}) async {
    final r = await dio.get('/clientes', queryParameters: {
      if (busca != null && busca.isNotEmpty) 'busca': busca,
    });
    return (r.data as List).map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Cliente> buscarCliente(String id) async {
    final r = await dio.get('/clientes/$id');
    return Cliente.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Cliente> criarCliente(Map<String, dynamic> body) async {
    final r = await dio.post('/clientes', data: body);
    return Cliente.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Cliente> atualizarCliente(String id, Map<String, dynamic> patch) async {
    final r = await dio.put('/clientes/$id', data: patch);
    return Cliente.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deletarCliente(String id) async {
    await dio.delete('/clientes/$id');
  }

  // ── Fechamentos ────────────────────────────────────────────────────────
  Future<List<ClienteFechamento>> listarFechamentos(String clienteId) async {
    final r = await dio.get('/clientes/$clienteId/fechamentos');
    return (r.data as List).map((j) => ClienteFechamento.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ClienteFechamento> buscarFechamento(String clienteId, String fechamentoId) async {
    final r = await dio.get('/clientes/$clienteId/fechamentos/$fechamentoId');
    return ClienteFechamento.fromJson(r.data as Map<String, dynamic>);
  }

  Future<({ClienteFechamento fechamento, List<Pedido> pedidos})> buscarFechamentoComPedidos(
    String clienteId,
    String fechamentoId,
  ) async {
    final r = await dio.get('/clientes/$clienteId/fechamentos/$fechamentoId');
    final data = r.data as Map<String, dynamic>;
    final pedidosJson = (data['pedidos'] as List?) ?? const [];
    return (
      fechamento: ClienteFechamento.fromJson(data),
      pedidos: pedidosJson.map((p) => Pedido.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  Future<ClienteFechamento> fecharFechamento(String clienteId, String fechamentoId, {String? observacao}) async {
    final r = await dio.post(
      '/clientes/$clienteId/fechamentos/$fechamentoId/fechar',
      data: {if (observacao != null) 'observacao': observacao},
    );
    return ClienteFechamento.fromJson(r.data as Map<String, dynamic>);
  }

  Future<ClienteFechamento> estenderFechamento(
    String clienteId,
    String fechamentoId,
    DateTime novaData, {
    String? observacao,
  }) async {
    final r = await dio.post(
      '/clientes/$clienteId/fechamentos/$fechamentoId/estender',
      data: {
        'nova_data': DateFormat('yyyy-MM-dd').format(novaData),
        if (observacao != null) 'observacao': observacao,
      },
    );
    return ClienteFechamento.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Configurações ──────────────────────────────────────────────────────
  Future<List<Configuracao>> listarConfiguracoes() async {
    final r = await dio.get('/configuracoes');
    return (r.data as List).map((j) => Configuracao.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Configuracao> atualizarConfiguracao(String chave, String valor) async {
    final r = await dio.put('/configuracoes/$chave', data: {'valor': valor});
    return Configuracao.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Orçamento ──────────────────────────────────────────────────────────
  Future<List<ItemPreco>> listarTabelaPreco() async {
    final r = await dio.get('/orcamento/tabela');
    return (r.data as List).map((j) => ItemPreco.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<String>> listarTecnicas() async {
    final r = await dio.get('/orcamento/tecnicas');
    return (r.data as List).map((e) => e as String).toList();
  }

  Future<OrcamentoResultado> calcularOrcamento(Map<String, dynamic> body) async {
    final r = await dio.post('/orcamento/calcular', data: body);
    return OrcamentoResultado.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Pagamentos ─────────────────────────────────────────────────────────
  Future<List<Pagamento>> listarPagamentos(String pedidoId) async {
    final r = await dio.get('/pagamentos/pedidos/$pedidoId');
    return (r.data as List).map((j) => Pagamento.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Pagamento> registrarPagamento(String pedidoId, Map<String, dynamic> body) async {
    final r = await dio.post('/pagamentos/pedidos/$pedidoId', data: body);
    return Pagamento.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deletarPagamento(String id) async {
    await dio.delete('/pagamentos/$id');
  }

  // ── Dashboard ──────────────────────────────────────────────────────────
  Future<DashboardStats> dashboardStats() async {
    final r = await dio.get('/dashboard/stats');
    return DashboardStats.fromJson(r.data as Map<String, dynamic>);
  }
}

// Provider que carrega URL do SharedPreferences
final serverUrlProvider = StateProvider<String>((ref) => defaultServerUrl);

final apiClientProvider = Provider<ApiClient>((ref) {
  final url = ref.watch(serverUrlProvider);
  return ApiClient(url);
});

Future<String> loadServerUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(prefsKeyServerUrl) ?? defaultServerUrl;
}

Future<void> saveServerUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(prefsKeyServerUrl, url);
}
