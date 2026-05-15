import 'package:empresa_server/calculadora_orcamento.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('CalculadoraOrcamento', () {
    late ({void Function() cleanup}) tmp;
    late CalculadoraOrcamento calc;

    setUp(() {
      final f = novoDb();
      tmp = (cleanup: f.cleanup);
      calc = CalculadoraOrcamento(f.db);
    });

    tearDown(() => tmp.cleanup());

    test('HIDRO FRENTE/COSTAS 12-24 — 1 cor sem matriz cobrada quando >= 150', () {
      final r = calc.calcular(
        tecnica: 'HIDRO',
        regiao: 'FRENTE/COSTAS',
        quantidade: 200,
        cores: 1,
      );
      expect(r['erro'], isNull);
      // faixa 100+: 1ª cor = 2.40
      expect(r['preco_por_peca'], closeTo(2.40, 0.001));
      expect(r['matriz_cobrada'], isFalse);
      expect(r['total'], closeTo(2.40 * 200, 0.01));
    });

    test('HIDRO FRENTE/COSTAS 25-50 — 3 cores + matriz cobrada (qtd < 150)', () {
      final r = calc.calcular(
        tecnica: 'HIDRO',
        regiao: 'FRENTE/COSTAS',
        quantidade: 30,
        cores: 3,
      );
      // 1ª cor 3.70 + 2 × 1.85 = 7.40
      expect(r['preco_por_peca'], closeTo(7.40, 0.001));
      expect(r['matriz_cobrada'], isTrue);
      // matriz_padrao_50x60 = 45 × 3 cores = 135
      expect(r['valor_matriz'], 45.0 * 3);
      expect(r['subtotal'], closeTo(7.40 * 30, 0.01));
      expect(r['total'], closeTo(7.40 * 30 + 135, 0.01));
    });

    test('ELASTIC BOTTOM/NUCA 51-100 — urgente aplica taxa', () {
      final r = calc.calcular(
        tecnica: 'ELASTIC',
        regiao: 'BOTTOM/NUCA',
        quantidade: 80,
        cores: 1,
        urgente: true,
      );
      // 1ª cor 2.50 × (1 + 25%) = 3.125
      expect(r['preco_por_peca'], closeTo(3.125, 0.01));
    });

    test('CROMIA — demais_cores == 1ª cor (cobra cada cor igual)', () {
      final r = calc.calcular(
        tecnica: 'CROMIA',
        regiao: 'FRENTE/COSTAS',
        quantidade: 200,
        cores: 5,
      );
      // 1ª 6.00 + 4 × 6.00 = 30.00
      expect(r['preco_por_peca'], closeTo(30.0, 0.001));
    });

    test('moletom_aberto soma 20%', () {
      final r = calc.calcular(
        tecnica: 'HIDRO',
        regiao: 'FRENTE/COSTAS',
        quantidade: 200,
        cores: 1,
        tipoPeca: 'moletom_aberto',
      );
      expect(r['preco_por_peca'], closeTo(2.40 * 1.20, 0.001));
    });

    test('moletom_fechado soma 60% combinado com urgente +25%', () {
      final r = calc.calcular(
        tecnica: 'HIDRO',
        regiao: 'FRENTE/COSTAS',
        quantidade: 200,
        cores: 1,
        tipoPeca: 'moletom_fechado',
        urgente: true,
      );
      // 2.40 × 1.60 × 1.25
      expect(r['preco_por_peca'], closeTo(2.40 * 1.60 * 1.25, 0.001));
    });

    test('combinação inexistente retorna erro estruturado', () {
      final r = calc.calcular(
        tecnica: 'INEXISTENTE',
        regiao: 'FRENTE/COSTAS',
        quantidade: 50,
      );
      expect(r['erro'], isNotNull);
    });

    test('cores=10 limita o multiplicador (cap interno do clamp)', () {
      final r = calc.calcular(
        tecnica: 'HIDRO',
        regiao: 'FRENTE/COSTAS',
        quantidade: 200,
        cores: 10,
      );
      // 2.40 + 9 × 1.20 = 13.20
      expect(r['preco_por_peca'], closeTo(13.20, 0.001));
    });
  });
}
