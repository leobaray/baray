import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agenda.dart';
import '../models/cliente.dart';
import '../models/cliente_fechamento.dart';
import '../models/configuracao.dart';
import '../models/dashboard.dart';
import '../models/orcamento.dart';
import '../models/pagamento.dart';
import '../models/pedido.dart';

/// URL padrão do servidor — sobrescreva no build com `--dart-define=SERVER_URL=...`
/// ou via configuração na primeira execução. Defaults pra localhost pra não
/// vazar topologia interna no código fonte (B-03).
const String defaultServerUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://localhost:8080',
);

const String prefsKeyServerUrl = 'server_url';
const String prefsKeyApiToken = 'api_token';

class ServerHealth {
  final bool online;
  final int latenciaMs;
  final String? versao;
  ServerHealth({required this.online, required this.latenciaMs, this.versao});
}

class ApiClient {
  final Dio dio;
  String baseUrl;
  String _apiToken;

  ApiClient(this.baseUrl, {String apiToken = ''})
      : _apiToken = apiToken,
        dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'content-type': 'application/json'},
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_apiToken.isNotEmpty) {
          options.headers['X-API-Key'] = _apiToken;
        }
        handler.next(options);
      },
    ));
  }

  void updateBaseUrl(String url) {
    baseUrl = url;
    dio.options.baseUrl = url;
  }

  void updateApiToken(String token) {
    _apiToken = token;
  }

  String get apiToken => _apiToken;

  Future<bool> health() async {
    try {
      final r = await dio.get('/health');
      return r.statusCode == 200 && r.data is Map && r.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Variante do [health] que também traz latência e versão do servidor.
  Future<ServerHealth> healthInfo() async {
    final sw = Stopwatch()..start();
    try {
      final r = await dio.get('/health');
      sw.stop();
      final data = r.data is Map ? r.data as Map : const {};
      return ServerHealth(
        online: data['ok'] == true,
        latenciaMs: sw.elapsedMilliseconds,
        versao: data['version'] as String?,
      );
    } catch (_) {
      sw.stop();
      return ServerHealth(online: false, latenciaMs: sw.elapsedMilliseconds);
    }
  }

  /// Retorna o valor atual do contador `proximo_lote` — útil pra telas
  /// administrativas mostrarem qual número um pedido novo vai pegar.
  Future<int?> proximoLote() async {
    try {
      final r = await dio.get('/configuracoes/proximo_lote');
      return (r.data as Map)['valor'] as int?;
    } catch (_) {
      return null;
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
      data: {'entregue_por': ?entreguePor},
    );
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Pedido> duplicarPedido(String id) async {
    final r = await dio.post('/pedidos/$id/duplicar');
    return Pedido.fromJson(r.data as Map<String, dynamic>);
  }

  // ── Clientes ───────────────────────────────────────────────────────────
  Future<List<Cliente>> listarClientes({
    String? busca,
    String? ordenar,
    bool comDebito = false,
  }) async {
    final r = await dio.get('/clientes', queryParameters: {
      if (busca != null && busca.isNotEmpty) 'busca': busca,
      if (ordenar != null && ordenar.isNotEmpty) 'ordenar': ordenar,
      if (comDebito) 'com_debito': 'true',
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
      data: {'observacao': ?observacao},
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
        'observacao': ?observacao,
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

  Future<List<String>> listarRegioes() async {
    final r = await dio.get('/orcamento/regioes');
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

  // ── Agenda ─────────────────────────────────────────────────────────────
  Future<AgendaOcupacao> agendaOcupacao(DateTime de, DateTime ate) async {
    final r = await dio.get('/agenda/ocupacao', queryParameters: {
      'de': DateFormat('yyyy-MM-dd').format(de),
      'ate': DateFormat('yyyy-MM-dd').format(ate),
    });
    return AgendaOcupacao.fromJson(r.data as Map<String, dynamic>);
  }
}

final serverUrlProvider = StateProvider<String>((ref) => defaultServerUrl);
final apiTokenProvider = StateProvider<String>((ref) => '');

final apiClientProvider = Provider<ApiClient>((ref) {
  final url = ref.watch(serverUrlProvider);
  final token = ref.watch(apiTokenProvider);
  return ApiClient(url, apiToken: token);
});

Future<String> loadServerUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(prefsKeyServerUrl) ?? defaultServerUrl;
}

Future<void> saveServerUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(prefsKeyServerUrl, url);
}

Future<String> loadApiToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(prefsKeyApiToken) ?? '';
}

Future<void> saveApiToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(prefsKeyApiToken, token);
}
