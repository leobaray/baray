import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/pagamento.dart';

final pagamentosProvider = FutureProvider.family.autoDispose<List<Pagamento>, String>(
  (ref, pedidoId) async {
    final api = ref.watch(apiClientProvider);
    return api.listarPagamentos(pedidoId);
  },
);
