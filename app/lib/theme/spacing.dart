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

/// Convenções de botão — fonte única para "quando usar o quê".
///
/// **FAB (FloatingActionButton):** ação primária de uma tela inteira.
///   - Use `FloatingActionButton.extended` em telas de lista (Pedidos,
///     Clientes, Dashboard) — texto explícito vence a ambiguidade do "+" solto.
///   - Use `FloatingActionButton` (round, sem label) só quando o ícone for
///     universalmente reconhecível (raro neste app).
///   - Posição padrão: `floatingActionButtonLocation: FloatingActionButtonLocation.endFloat`.
///
/// **IconButton:** ações dentro de cards/linhas ou na AppBar.
///   - Sempre garanta touch target de 44×44 dp:
///       `IconButton(constraints: BoxConstraints(minWidth: 44, minHeight: 44))`
///     ou `IconButton.filledTonal/.outlined` (já têm padding adequado).
///   - Use `tooltip` para acessibilidade — todo IconButton precisa.
///
/// **FilledButton / TextButton / OutlinedButton:** ações inline em forms,
/// diálogos, footers. Não confundir com FAB.
///
/// **Resumo:**
/// | Onde            | Use                              |
/// |-----------------|----------------------------------|
/// | Tela primária   | `FAB.extended` com label         |
/// | AppBar          | `IconButton` com tooltip         |
/// | Dentro de card  | `IconButton` 44×44 com tooltip   |
/// | Form / dialog   | `FilledButton` / `TextButton`    |
class AppButtons {
  AppButtons._();

  /// Touch target mínimo (WCAG 2.5.5 AA recomenda 44dp).
  static const double minTouchTarget = 44;
}

/// Tokens de border radius. Use em vez de hardcodar `BorderRadius.circular(N)`.
class AppRadius {
  AppRadius._();

  /// Radius mínimo (4px) — tags, badges densos.
  static const double xs = 4;

  /// Radius pequeno (8px) — chips, pills internos, micro-cards.
  static const double sm = 8;

  /// Radius médio (12px) — inputs, dropdowns, banners.
  static const double md = 12;

  /// Radius grande (16px) — cards padrão, FABs.
  static const double lg = 16;

  /// Radius extra (20px) — bottom sheets, dialogs.
  static const double xl = 20;

  /// Forma pill (999) — chips arredondados, status pills.
  static const double pill = 999;
}
