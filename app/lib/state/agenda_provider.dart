import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/agenda.dart';

/// Chave que identifica um range de datas (inclusivo) — usada pra cachear
/// a ocupação de uma semana / mês / timeline.
class AgendaRange {
  final DateTime de;
  final DateTime ate;
  const AgendaRange(this.de, this.ate);

  @override
  bool operator ==(Object other) =>
      other is AgendaRange &&
      other.de.year == de.year &&
      other.de.month == de.month &&
      other.de.day == de.day &&
      other.ate.year == ate.year &&
      other.ate.month == ate.month &&
      other.ate.day == ate.day;

  @override
  int get hashCode => Object.hash(de.year, de.month, de.day, ate.year, ate.month, ate.day);
}

final agendaOcupacaoProvider =
    FutureProvider.family.autoDispose<AgendaOcupacao, AgendaRange>(
  (ref, range) async {
    final api = ref.watch(apiClientProvider);
    return api.agendaOcupacao(range.de, range.ate);
  },
);
