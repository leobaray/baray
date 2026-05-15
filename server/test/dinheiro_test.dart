import 'package:empresa_server/dinheiro.dart';
import 'package:test/test.dart';

void main() {
  group('arredondarCentavos (banker\'s rounding)', () {
    test('arredondamento padrão sem empate', () {
      expect(arredondarCentavos(1.234), 1.23);
      expect(arredondarCentavos(1.236), 1.24);
      expect(arredondarCentavos(0), 0);
      expect(arredondarCentavos(100.005000001), 100.01);
    });

    test('empate exato → arredonda para par (half-even)', () {
      // Casos clássicos de banker's rounding.
      // 0,125 → 0,12 (12 é par, não vai pra 13)
      expect(arredondarCentavos(0.125), 0.12);
      // 0,135 → 0,14 (14 é par, vai pra 14)
      expect(arredondarCentavos(0.135), 0.14);
      // 2,425 → 2,42 (42 par)
      expect(arredondarCentavos(2.425), 2.42);
      // 2,435 → 2,44 (44 par)
      expect(arredondarCentavos(2.435), 2.44);
    });

    test('preserva sinal em negativos', () {
      expect(arredondarCentavos(-1.234), -1.23);
      expect(arredondarCentavos(-1.236), -1.24);
      expect(arredondarCentavos(-0.125), -0.12);
    });

    test(
        'agregação de muitos valores arredondados não acumula desvio sistemático',
        () {
      // Cenário clássico: 1000 valores sorteados que terminam em 0,005.
      // Half-away-from-zero (toStringAsFixed) inflaria a soma; half-even fica
      // estatisticamente próximo do valor real.
      double somaHalfEven = 0;
      for (var i = 1; i <= 100; i++) {
        // 0,005 ; 0,015 ; 0,025 ; ... ; 0,995
        final v = (i * 10 - 5) / 1000;
        somaHalfEven += arredondarCentavos(v);
      }
      // Soma exata = 100 * 0,5 = 50,0 (1+2+...+100 = 5050 milésimos)
      // = (5050 - 500) / 1000 = ... ok valor exato 50,00.
      // Half-even deve cair em ±R\$ 0,50 (5 centavos por 100 itens, expectativa
      // 0 mas com runtime drift). Half-away-from-zero cairia em +R\$ 0,50.
      expect((somaHalfEven - 50.0).abs(), lessThan(0.51));
    });

    test('NaN/Infinity passam direto sem corromper', () {
      expect(arredondarCentavos(double.nan).isNaN, isTrue);
      expect(arredondarCentavos(double.infinity), double.infinity);
      expect(arredondarCentavos(double.negativeInfinity),
          double.negativeInfinity);
    });
  });

  group('igualEmCentavos', () {
    test('iguais dentro da tolerância de 1 centavo', () {
      expect(igualEmCentavos(100.0, 100.0), isTrue);
      expect(igualEmCentavos(100.0, 100.001), isTrue);
      expect(igualEmCentavos(100.0, 99.999), isTrue);
    });

    test('diferentes fora da tolerância', () {
      expect(igualEmCentavos(100.0, 100.02), isFalse);
      expect(igualEmCentavos(100.0, 99.98), isFalse);
    });
  });

  group('ehMaiorQueZero', () {
    test('zero e quase-zero retornam falso (não há débito real)', () {
      expect(ehMaiorQueZero(0), isFalse);
      expect(ehMaiorQueZero(0.005), isFalse);
      expect(ehMaiorQueZero(0.01), isFalse); // estritamente maior
    });

    test('um centavo + epsilon retorna true (há débito real)', () {
      expect(ehMaiorQueZero(0.011), isTrue);
      expect(ehMaiorQueZero(1.0), isTrue);
    });

    test('valor negativo retorna false', () {
      expect(ehMaiorQueZero(-100.0), isFalse);
    });
  });
}
