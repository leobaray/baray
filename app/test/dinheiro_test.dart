import 'package:baray/util/dinheiro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('arredondarCentavos (banker\'s rounding)', () {
    test('arredondamento padrão sem empate', () {
      expect(arredondarCentavos(1.234), 1.23);
      expect(arredondarCentavos(1.236), 1.24);
      expect(arredondarCentavos(0), 0);
    });

    test('empate exato → arredonda para par (half-even)', () {
      // 0,125 → 0,12 (12 é par, não vai pra 13)
      expect(arredondarCentavos(0.125), 0.12);
      // 0,135 → 0,14 (14 é par)
      expect(arredondarCentavos(0.135), 0.14);
      expect(arredondarCentavos(2.425), 2.42);
      expect(arredondarCentavos(2.435), 2.44);
    });

    test('preserva sinal em negativos', () {
      expect(arredondarCentavos(-1.234), -1.23);
      expect(arredondarCentavos(-0.125), -0.12);
    });

    // Re-audit (Fase 5 #3 / A-04 retry): epsilon apertado de 1e-9 → 1e-12.
    // Valores pequenos que caem exatamente em x.5 após `*100` continuam
    // sendo tratados como tie (banker's correto). A diferença é que drifts
    // genuínos > 1e-12 não recebem mais tratamento de tie indevidamente.
    test('valores pequenos nos limites de centavo', () {
      // 0.005 → tie → 0 é par → 0.00
      expect(arredondarCentavos(0.005), 0.00);
      // 0.105 → tie → 10 é par → 0.10
      expect(arredondarCentavos(0.105), 0.10);
      // 0.115 → tie → 11 é ímpar → 12 → 0.12
      expect(arredondarCentavos(0.115), 0.12);
    });
  });

  group('ehMaiorQueZero / igualEmCentavos', () {
    test('zero e resíduo < 1 centavo retornam falso', () {
      expect(ehMaiorQueZero(0), isFalse);
      expect(ehMaiorQueZero(0.005), isFalse);
      expect(ehMaiorQueZero(0.01), isFalse);
    });

    test('débito de 2 centavos retorna true', () {
      expect(ehMaiorQueZero(0.02), isTrue);
    });

    test('igualEmCentavos tolera 1 centavo de diferença', () {
      expect(igualEmCentavos(100.0, 100.005), isTrue);
      expect(igualEmCentavos(100.0, 100.02), isFalse);
    });
  });
}
