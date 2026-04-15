/// Tokens de espaçamento usados em todo o app.
///
/// Regra: escolha o nível, não o número. Se um valor novo surgir, adicione aqui
/// antes de hardcodar na tela — padding/gap têm que ser auditáveis.
class AppSpacing {
  AppSpacing._();

  // Gaps entre elementos dentro de um card/row.
  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;
  static const double gapXl = 24;

  // Padding interno de cards.
  static const double cardPaddingSm = 12;
  static const double cardPaddingMd = 16;
  static const double cardPaddingLg = 20;

  // Padding padrão de scrollables (listviews/forms).
  static const double screenPaddingH = 16;
  static const double screenPaddingV = 16;

  // Respiro inferior do floating action button.
  static const double fabBottomPad = 96;
}
