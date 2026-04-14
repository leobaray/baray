import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../models/pedido.dart';

class PedidosFiltro {
  final String? status;
  final String? statusPagamento;
  final String? busca;
  final bool urgenteOnly;
  final String ordenar;

  const PedidosFiltro({
    this.status,
    this.statusPagamento,
    this.busca,
    this.urgenteOnly = false,
    this.ordenar = 'lote',
  });

  PedidosFiltro copyWith({
    String? status,
    String? statusPagamento,
    String? busca,
    bool? urgenteOnly,
    String? ordenar,
    bool resetStatus = false,
    bool resetStatusPagamento = false,
    bool resetBusca = false,
  }) {
    return PedidosFiltro(
      status: resetStatus ? null : (status ?? this.status),
      statusPagamento: resetStatusPagamento ? null : (statusPagamento ?? this.statusPagamento),
      busca: resetBusca ? null : (busca ?? this.busca),
      urgenteOnly: urgenteOnly ?? this.urgenteOnly,
      ordenar: ordenar ?? this.ordenar,
    );
  }

  bool get algumFiltroAtivo =>
      status != null || statusPagamento != null || (busca?.isNotEmpty ?? false) || urgenteOnly;
}

final pedidosFiltroProvider = StateProvider<PedidosFiltro>((ref) => const PedidosFiltro());

final pedidosProvider = FutureProvider.autoDispose<List<Pedido>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filtro = ref.watch(pedidosFiltroProvider);
  return api.listarPedidos(
    status: filtro.status,
    statusPagamento: filtro.statusPagamento,
    busca: filtro.busca,
    urgente: filtro.urgenteOnly ? true : null,
    ordenar: filtro.ordenar,
  );
});

final pedidoProvider = FutureProvider.family.autoDispose<Pedido, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  return api.buscarPedido(id);
});
