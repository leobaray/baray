import 'package:flutter/material.dart';

/// Tamanhos tipográficos padronizados pra tabela densa.
///
/// O design parte de planilha — densidade alta, fontes pequenas mas legíveis.
/// Use estes valores em vez de hardcodar `fontSize: 13` etc.
class AppType {
  AppType._();

  /// Texto de linha de tabela / valor numérico.
  static const double row = 13;

  /// Cabeçalho de coluna em tabela densa.
  static const double colHeader = 11;

  /// Lote / código identificador (monoespaçado quando possível).
  static const double code = 12;

  /// Pill de status compacto.
  static const double pill = 11;

  /// Texto auxiliar (legenda, telefone, segunda linha).
  static const double caption = 11.5;
}

/// Altura mínima de linha de tabela densa — clicável e confortável.
const double kRowMinHeight = 44;

/// Altura do cabeçalho de tabela densa.
const double kHeaderHeight = 36;

/// Densidade visual padrão pro app — apertada mas confortável.
const VisualDensity kAppDensity = VisualDensity(horizontal: -1, vertical: -1);
