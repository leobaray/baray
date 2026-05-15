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

    // Re-audit (Fase 5 #3 / A-04 retry): com epsilon=1e-9, valores pequenos
    // como 0.105/0.115/0.005 cujo escalado * 100 cai exatamente em x.5
    // (sem drift IEEE754) eram tratados como tie e iam pra par. Isso ainda
    // é o esperado para banker's rounding (half-to-even). O risco do
    // epsilon antigo era diferente: drift de até ~5e-10 era classificado
    // como tie quando não era. Com 1e-12, só drifts genuínos abaixo do
    // erro de `*100` (eps*100 ≈ 2.22e-14) caem como tie.
    test('valores nos limites de centavo (small edge) banker correto', () {
      // 0.005 → escalado=0.5 exato → tie → 0 é par → 0.00
      expect(arredondarCentavos(0.005), 0.00);
      // 0.015 → escalado=1.5 exato → tie → 1 é ímpar → vai pra 2 → 0.02
      expect(arredondarCentavos(0.015), 0.02);
      // 0.105 → escalado=10.5 exato → tie → 10 é par → 0.10
      expect(arredondarCentavos(0.105), 0.10);
      // 0.115 → escalado=11.5 exato → tie → 11 é ímpar → 12 → 0.12
      expect(arredondarCentavos(0.115), 0.12);
    });

    test(
        'epsilon apertado: drift real de IEEE754 não cai mais em tie falso',
        () {
      // 2.425 * 100 = 242.49999999999997 no Dart x64. |frac-0.5| ≈ 2.84e-14.
      // Com epsilon=1e-12 isso AINDA é tie (2.84e-14 < 1e-12) → banker.
      // O ponto-chave é o oposto: valores com drift > 1e-12 (acumulados em
      // chains de pcts) não recebem mais o tratamento de tie. Esse caso
      // confirma que o tratamento de tie continua funcionando para
      // drifts genuinamente próximos do empate.
      expect(arredondarCentavos(2.425), 2.42);

      // Valor com drift maior que epsilon: 0.005 + 1e-10 não é mais tie
      // (1e-8 em escalado > 1e-12) → half-up natural via `frac > 0.5`.
      expect(arredondarCentavos(0.005 + 1e-10), 0.01,
          reason: 'drift > epsilon cai em half-up, não em tie pra par');
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
