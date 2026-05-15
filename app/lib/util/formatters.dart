import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatters cached em top-level — evita recriar [NumberFormat] / [DateFormat]
/// em cada `build()`. `intl` carrega os símbolos do locale na construção, o que
/// é caro pra listas com muitos rebuilds.
class AppFormatters {
  AppFormatters._();

  static final NumberFormat moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  /// Moeda sem casas decimais — listagens compactas (R$ 1.234).
  static final NumberFormat moedaInteira =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 0);

  /// Formato compacto sem símbolo (1.234,56) — útil pra inputs.
  static final NumberFormat decimalBR = NumberFormat.decimalPattern('pt_BR');

  static final DateFormat data = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat dataCurta = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final DateFormat hora = DateFormat('HH:mm', 'pt_BR');
  static final DateFormat diaSemana = DateFormat('EEE', 'pt_BR');
  static final DateFormat diaMesExtenso = DateFormat("d 'de' MMMM", 'pt_BR');
  static final DateFormat isoData = DateFormat('yyyy-MM-dd');
}

/// Converte um texto digitado pelo usuário para `double`. Aceita:
///   `1.234,56`  → 1234.56  (BR — separador de milhar `.` e decimal `,`)
///   `1234,56`   → 1234.56
///   `1234.56`   → 1234.56  (US — heurística: tem `.` mas não tem `,`)
///   `1234`      → 1234
///   `R$ 12,34`  → 12.34    (símbolos descartados)
///
/// Retorna `null` se nada parseável for encontrado.
double? parseValorBR(String texto) {
  var t = texto.trim();
  if (t.isEmpty) return null;
  // Descarta tudo que não é dígito, vírgula, ponto ou sinal negativo.
  t = t.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (t.isEmpty) return null;

  final temVirgula = t.contains(',');
  final temPonto = t.contains('.');

  // Caso BR: vírgula é o separador decimal.
  if (temVirgula) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  // Caso US: só tem ponto → assumir decimal.
  // Heurística pra evitar tratar "1.234" (US milhar) como 1234 quando não há
  // dígitos após o ponto na posição de "centavos": se há exatamente UM ponto e
  // 1–2 dígitos depois dele, é decimal. Caso contrário (1.234) tratamos como
  // milhar inadvertido — interpretação BR mais conservadora.
  if (temPonto) {
    final pontos = '.'.allMatches(t).length;
    final partes = t.split('.');
    final decimalLikely = pontos == 1 &&
        partes.length == 2 &&
        partes[1].isNotEmpty &&
        partes[1].length <= 2;
    if (decimalLikely) return double.tryParse(t);
    // Mais de um ponto, ou 3+ dígitos após (ex: 1.234) → trata `.` como milhar
    return double.tryParse(t.replaceAll('.', ''));
  }

  return double.tryParse(t);
}

/// Formata um `double` como valor BRL sem o símbolo (`1.234,56`).
String formatValorBR(double valor) {
  return _formatadorBR.format(valor);
}

final NumberFormat _formatadorBR = NumberFormat('#,##0.00', 'pt_BR');

/// `TextInputFormatter` de moeda BR no estilo accumulador de centavos.
///
/// Trata todos os dígitos digitados como centavos e formata automaticamente:
///   "1"       → "0,01"
///   "12"      → "0,12"
///   "1234"    → "12,34"
///   "123456"  → "1.234,56"
///
/// Vantagem: o usuário não consegue digitar um formato inválido. Valor exibido
/// é exatamente o que o `parseValorBR` vai interpretar no submit.
class BrlInputFormatter extends TextInputFormatter {
  const BrlInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) {
      return const TextEditingValue();
    }
    // Limita a 9 dígitos (max R$ 9.999.999,99) — protege contra overflow.
    final ds = digitos.length > 9 ? digitos.substring(0, 9) : digitos;
    final cents = int.parse(ds);
    final valor = cents / 100;
    final formatado = _formatadorBR.format(valor);
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
