import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../models/cliente.dart';

class ClientesFiltro {
  final String? busca;
  final String ordenar; // nome | gasto | devendo | pedidos | recente
  final bool comDebito;

  const ClientesFiltro({
    this.busca,
    this.ordenar = 'nome',
    this.comDebito = false,
  });

  ClientesFiltro copyWith({
    String? busca,
    String? ordenar,
    bool? comDebito,
    bool resetBusca = false,
  }) {
    return ClientesFiltro(
      busca: resetBusca ? null : (busca ?? this.busca),
      ordenar: ordenar ?? this.ordenar,
      comDebito: comDebito ?? this.comDebito,
    );
  }

  bool get algumFiltroAtivo =>
      (busca?.isNotEmpty ?? false) || ordenar != 'nome' || comDebito;
}

final clientesFiltroProvider = StateProvider<ClientesFiltro>((ref) => const ClientesFiltro());

/// Mantido pra compat com o form de cliente antigo — apenas a string de busca.
/// Espelha o campo `busca` do [clientesFiltroProvider].
final clientesBuscaProvider = StateProvider.autoDispose<String>((ref) {
  return ref.watch(clientesFiltroProvider).busca ?? '';
});

final clientesProvider = FutureProvider.autoDispose<List<Cliente>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filtro = ref.watch(clientesFiltroProvider);
  return api.listarClientes(
    busca: filtro.busca,
    ordenar: filtro.ordenar,
    comDebito: filtro.comDebito,
  );
});

final clienteDetalheProvider = FutureProvider.family.autoDispose<Cliente, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  return api.buscarCliente(id);
});
