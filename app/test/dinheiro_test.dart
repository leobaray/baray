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
