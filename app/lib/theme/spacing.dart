/// Tokens de espaçamento usados em todo o app.
///
/// Regra: escolha o nível, não o número. Se um valor novo surgir, adicione
/// aqui antes de hardcodar na tela — padding/gap têm que ser auditáveis.
class AppSpacing {
  AppSpacing._();

  /// Gap pequeno entre elementos próximos (ícone+texto, chips lado a lado).
  static const double gapSm = 8;

  /// Gap médio entre linhas relacionadas dentro de um card.
  static const double gapMd = 12;

  /// Gap grande — padding interno de cards e separação entre seções.
  static const double gapLg = 16;
}
