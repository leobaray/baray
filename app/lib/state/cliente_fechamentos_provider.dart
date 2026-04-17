import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/cliente_fechamento.dart';


final fechamentosProvider = FutureProvider.family.autoDispose<List<ClienteFechamento>, String>((
  ref,
  clienteId,
) async {
  final api = ref.watch(apiClientProvider);
  return api.listarFechamentos(clienteId);
});

final fechamentoAtualProvider = FutureProvider.family.autoDispose<ClienteFechamento?, String>((
  ref,
  clienteId,
) async {
  final fechamentos = await ref.watch(fechamentosProvider(clienteId).future);
  for (final f in fechamentos) {
    if (f.aberto) return f;
  }
  return null;
});