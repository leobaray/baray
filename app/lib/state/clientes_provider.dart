import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../models/cliente.dart';

final clientesBuscaProvider = StateProvider<String>((ref) => '');

final clientesProvider = FutureProvider.autoDispose<List<Cliente>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final busca = ref.watch(clientesBuscaProvider);
  return api.listarClientes(busca: busca.isEmpty ? null : busca);
});

final clienteDetalheProvider = FutureProvider.family.autoDispose<Cliente, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  return api.buscarCliente(id);
});
