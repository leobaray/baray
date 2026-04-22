/// Tokens de espaçamento e raio usados em todo o app.
///
/// Regra: escolha o nível, não o número. Se um valor novo surgir, adicione
/// aqui antes de hardcodar na tela — padding/gap têm que ser auditáveis.
class AppSpacing {
  AppSpacing._();

  // ── Gaps (entre elementos) ─────────────────────────────────────────────
  /// Gap mínimo (4px) — entre ícone e texto adjacentes.
  static const double gapXs = 4;

  /// Gap pequeno (8px) — entre elementos próximos (chips lado a lado).
  static const double gapSm = 8;

  /// Gap médio (12px) — entre linhas relacionadas dentro de um card.
  static const double gapMd = 12;

  /// Gap grande (16px) — separação entre seções dentro de uma tela.
  static const double gapLg = 16;

  /// Gap extra (24px) — separação entre blocos visuais distintos.
  static const double gapXl = 24;

  // ── Padding interno ────────────────────────────────────────────────────
  /// Padding compacto (8px) — linhas de tabela densa.
  static const double padXs = 8;

  /// Padding pequeno (12px) — cards densos, linhas clicáveis.
  static const double padSm = 12;

  /// Padding médio (16px) — cards padrão.
  static const double padMd = 16;

  /// Padding grande (20px) — cards de destaque ou seções.
  static const double padLg = 20;
}

/// Raios de borda padronizados.
class AppRadius {
  AppRadius._();

  /// Raio pequeno (6px) — badges, pills compactos.
  static const double sm = 6;

  /// Raio médio (10px) — inputs, botões, linhas de tabela.
  static const double md = 10;

  /// Raio grande (14px) — cards.
  static const double lg = 14;

  /// Pill — botões redondos / chips.
  static const double pill = 999;
}
