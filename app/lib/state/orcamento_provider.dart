import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/orcamento.dart';

final tabelaPrecoProvider = FutureProvider.autoDispose<List<ItemPreco>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.listarTabelaPreco();
});

final tecnicasProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.listarTecnicas();
});
