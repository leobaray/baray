import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/configuracao.dart';

final configuracoesProvider = FutureProvider<List<Configuracao>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.listarConfiguracoes();
});
