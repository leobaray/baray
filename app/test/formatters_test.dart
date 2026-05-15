import 'package:baray/util/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseValorBR', () {
    test('formato BR com vírgula decimal: 1.234,56', () {
      expect(parseValorBR('1.234,56'), 1234.56);
    });

    test('BR sem milhar: 1234,56', () {
      expect(parseValorBR('1234,56'), 1234.56);
    });

    test('BR com símbolo: R\$ 12,34', () {
      expect(parseValorBR(r'R$ 12,34'), 12.34);
    });

    test('US com ponto decimal: 123.45 (resolve A-05)', () {
      // Caso que antes virava 12345.0 (100x maior!) — agora vira 123.45.
      expect(parseValorBR('123.45'), 123.45);
    });

    test('US com 1 dígito decimal: 12.5', () {
      expect(parseValorBR('12.5'), 12.5);
    });

    test('ambíguo "1.234" interpretado como milhar BR (3 dígitos após .)', () {
      // "1.234" → 1234 (sem decimal). É o caso comum em listas BR.
      expect(parseValorBR('1.234'), 1234);
    });

    test('múltiplos pontos viram milhares: 1.234.567', () {
      expect(parseValorBR('1.234.567'), 1234567);
    });

    test('inteiro puro: 100', () {
      expect(parseValorBR('100'), 100);
    });

    test('texto vazio → null', () {
      expect(parseValorBR(''), isNull);
      expect(parseValorBR('   '), isNull);
    });

    test('lixo no input descartado', () {
      expect(parseValorBR('abc 99,00 def'), 99);
    });
  });

  group('AppFormatters', () {
    test('moeda BR formatação básica', () {
      // Valor 1234.5 → "R\$ 1.234,50"
      final out = AppFormatters.moeda.format(1234.5);
      expect(out, contains('1.234,50'));
      expect(out, contains(r'R$'));
    });

    test('moedaInteira sem casas decimais', () {
      final out = AppFormatters.moedaInteira.format(1234);
      expect(out, contains('1.234'));
      expect(out, isNot(contains(',')));
    });
  });

  group('formatValorBR', () {
    test('inteiro vira com duas casas', () {
      expect(formatValorBR(100), '100,00');
    });

    test('milhar com separador BR', () {
      expect(formatValorBR(1234.56), '1.234,56');
    });

    test('arredonda centavos', () {
      expect(formatValorBR(0.555), '0,56');
    });
  });

  group('BrlInputFormatter', () {
    const fmt = BrlInputFormatter();

    TextEditingValue apply(String text) {
      return fmt.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );
    }

    test('1 dígito vira 0,01', () {
      expect(apply('1').text, '0,01');
    });

    test('123 vira 1,23', () {
      expect(apply('123').text, '1,23');
    });

    test('123456 vira 1.234,56', () {
      expect(apply('123456').text, '1.234,56');
    });

    test('texto vazio fica vazio', () {
      expect(apply('').text, '');
    });

    test('não-dígitos são descartados', () {
      expect(apply('R\$ 1.234,56').text, '1.234,56');
    });

    test('cursor vai pro fim', () {
      final r = apply('100');
      expect(r.selection.baseOffset, r.text.length);
    });
  });
}
