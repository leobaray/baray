/// Helpers de aritmética monetária no app — espelham `server/lib/dinheiro.dart`.
///
/// **Contexto (AUDIT A-04):** valores monetários transitam como `double`
/// IEEE 754 entre app e server. Comparações como `valorDevendo > 0.01`
/// existiam espalhadas com magic numbers; centralizamos aqui.
///
/// Migração full pra centavos inteiros é follow-up tracked no AUDIT.
library;

/// Tolerância de comparação monetária — R\$ 0,01.
///
/// Substitui o literal `0.01` usado em telas/widgets pra distinguir "tem
/// débito" vs "resíduo de arredondamento de IEEE 754".
const double kTolerancaCentavos = 0.01;

/// Arredonda para centavos usando **banker's rounding** (half-to-even).
///
/// Diferença vs `toStringAsFixed(2)`: half-even é estatisticamente neutro
/// em sequências de arredondamento (não infla nem deflaciona somatórios).
///
/// Exemplos:
///   `arredondarCentavos(0.125)` → `0.12`
///   `arredondarCentavos(0.135)` → `0.14`
///   `arredondarCentavos(0.125000001)` → `0.13`
double arredondarCentavos(double valor) {
  if (valor.isNaN || valor.isInfinite) return valor;
  final escalado = valor * 100;
  final inteiro = escalado.truncateToDouble();
  final frac = escalado - inteiro;
  const epsilon = 1e-9;
  int cents;
  if (valor >= 0) {
    if ((frac - 0.5).abs() < epsilon) {
      final inteiroInt = inteiro.toInt();
      cents = inteiroInt.isEven ? inteiroInt : inteiroInt + 1;
    } else if (frac > 0.5) {
      cents = inteiro.toInt() + 1;
    } else {
      cents = inteiro.toInt();
    }
  } else {
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
