import 'package:flutter/material.dart';

/// Tamanhos tipográficos padronizados — fonte única de verdade pra fontSize
/// no app. O design parte de planilha, então a tabela densa usa tamanhos
/// menores que o `theme.textTheme` Material 3 default.
///
/// **Convenção:**
/// - Para tabelas/células densas e pills: use estes tokens (`AppType.row`,
///   `AppType.colHeader`, `AppType.pill`).
/// - Para headers e títulos prominentes: prefira `theme.textTheme.titleSmall`,
///   `theme.textTheme.titleMedium` etc — herdam fonte e letterSpacing globais.
/// - Para body/legendas em cards densos: use `AppType.body`, `AppType.bodyLg`.
class AppType {
  AppType._();

  // ── Tabela densa ───────────────────────────────────────────────────────
  /// Texto de linha de tabela / valor numérico (13).
  static const double row = 13;

  /// Cabeçalho de coluna em tabela densa (12).
  static const double colHeader = 12;

  /// Lote / código identificador, monoespaçado quando possível (12).
  static const double code = 12;

  /// Pill de status compacto (12).
  static const double pill = 12;

  /// Texto auxiliar (legenda, telefone, segunda linha) (12).
  static const double caption = 12;

  // ── Body/legendas (cards densos) ───────────────────────────────────────
  /// Label uppercase pequena (filtros, hint chips) (11).
  static const double overline = 11;

  /// Body secundário (12.5) — subtítulos compactos.
  static const double bodySm = 12.5;

  /// Body padrão (13) — sub-texto de cards, descrições.
  static const double body = 13;

  /// Body proeminente (14) — texto principal de cards.
  static const double bodyLg = 14;

  // ── Títulos densos ─────────────────────────────────────────────────────
  /// Título compacto de bloco interno (15).
  static const double title = 15;

  /// Título proeminente em barras/headers densos (17).
  static const double titleLg = 17;

  /// Valor de destaque (KPI, total grande) (20).
  static const double display = 20;
}

/// Altura mínima de linha de tabela densa — clicável e confortável.
const double kRowMinHeight = 44;

/// Altura do cabeçalho de tabela densa.
const double kHeaderHeight = 36;

/// Densidade visual padrão pro app — apertada mas confortável.
const VisualDensity kAppDensity = VisualDensity(horizontal: -1, vertical: -1);
