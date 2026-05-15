/// Helpers de aritmética monetária para mitigar desvio acumulado de IEEE 754.
///
/// **Contexto (AUDIT A-04):** valores monetários são armazenados em SQLite
/// `REAL` (= IEEE 754 64-bit, igual ao `double` Dart). Multiplicações encadeadas
/// (preço × 1,25 urgência × 1,60 moletom × quantidade) acumulam erro de
/// representação. Para uma operação isolada o erro é ~10⁻¹³, mas em agregações
/// (`SUM` de fechamento de mês) e em chains de pcts ímpares o erro pode chegar
/// na casa do centavo.
///
/// **Solução completa (não aplicada neste commit):** migrar schema para
/// `valor_centavos INTEGER`. Requer migration v9, refactor de models, queries
/// de SUM, validators, e camada de UI. Tracked como follow-up de produto.
///
/// **Solução parcial aplicada aqui:** centralizar tolerância e arredondamento
/// num único módulo, usar arredondamento banker's (`HALF_EVEN`) em pontos onde
/// o resultado é exibido/persistido, e tornar comparações monetárias
/// inequívocas via [igualEmCentavos]/[ehMaiorQueZero].
library;

/// Tolerância de comparação monetária — R\$ 0,01.
///
/// Usada em pontos onde se compara `valor_pago >= valor_total` ou
/// `valor_devendo > 0`. Substitui o literal `0.01` espalhado pelo código.
const double kTolerancaCentavos = 0.01;

/// Arredonda para centavos usando **banker's rounding** (half-to-even).
///
/// Diferença em relação a `toStringAsFixed(2)` (que usa half-away-from-zero):
/// em sequências de arredondamentos, half-even é estatisticamente neutro —
/// não tende a inflar nem deflar o total. É o padrão de contabilidade
/// (ABNT/IEEE 754 §4.3.3) e o que o Decimal de Java/Python usam por default.
///
/// Exemplos:
///   `arredondarCentavos(0.125)` → `0.12` (não 0.13 — desempata pra par)
///   `arredondarCentavos(0.135)` → `0.14`
///   `arredondarCentavos(0.125000001)` → `0.13` (não há empate)
double arredondarCentavos(double valor) {
  if (valor.isNaN || valor.isInfinite) return valor;
  // Trabalha em centavos como int64 para evitar segundo erro de representação
  // no fator 100.0. `(valor * 100).round()` usa half-away-from-zero — não
  // queremos isso. Implementamos half-even manualmente.
  final escalado = valor * 100;
  final inteiro = escalado.truncateToDouble();
  final frac = escalado - inteiro;
  // Margem de segurança para empates "quase exatos" introduzidos pelo *100
  // (ex: 0.125 * 100 = 12.500000000000002 em alguns runtimes).
  // Re-audit (Fase 5 #3): 1e-9 era grande demais — entradas reais com erro
  // IEEE754 acumulado caíam em half-even quando deveriam half-up
  // (ex.: 0.105 = 0.1050000000000000044 — escalado=10.500000000000004,
  // frac-0.5 ≈ 4e-15, ainda dentro de 1e-12). Apertamos para 1e-12 que é
  // ~10x o erro relativo máximo de uma única multiplicação por 100 em IEEE
  // 754 double (eps ≈ 2.22e-16, * 100 = 2.22e-14).
  const epsilon = 1e-12;
  int cents;
  if (valor >= 0) {
    if ((frac - 0.5).abs() < epsilon) {
      // Empate: arredonda para par.
      final inteiroInt = inteiro.toInt();
      cents = inteiroInt.isEven ? inteiroInt : inteiroInt + 1;
    } else if (frac > 0.5) {
      cents = inteiro.toInt() + 1;
    } else {
      cents = inteiro.toInt();
    }
  } else {
    // Para negativos `truncateToDouble` arredonda em direção a zero;
    // `frac` é negativo, comparamos com -0.5.
    if ((frac + 0.5).abs() < epsilon) {
      final inteiroInt = inteiro.toInt();
      cents = inteiroInt.isEven ? inteiroInt : inteiroInt - 1;
    } else if (frac < -0.5) {
      cents = inteiro.toInt() - 1;
    } else {
      cents = inteiro.toInt();
    }
  }
  return cents / 100;
}

/// `true` se [a] e [b] são iguais com tolerância de [kTolerancaCentavos].
bool igualEmCentavos(double a, double b) {
  return (a - b).abs() < kTolerancaCentavos;
}

/// `true` se [valor] é estritamente maior que zero descontando a tolerância
/// (i.e. há débito/saldo real, não apenas resíduo de arredondamento).
bool ehMaiorQueZero(double valor) {
  return valor > kTolerancaCentavos;
}
