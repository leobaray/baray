/// Breakpoints de responsividade compartilhados.
///
/// Use estas constantes em vez de hardcodar larguras — assim o limiar entre
/// mobile/tablet/desktop fica auditável num único lugar.
class AppBreakpoints {
  AppBreakpoints._();

  /// Mobile estreito → navegação em bottom bar, layout empilhado.
  /// Acima disso: rail lateral + espaçamento maior.
  static const double compact = 720;

  /// Tela de detalhe grande: forms/listas lado a lado.
  static const double medium = 900;

  /// Desktop: cards do dashboard em grid 2x2.
  static const double wide = 1100;

  /// Extra wide: agenda em múltiplas colunas.
  static const double extraWide = 1200;
}
