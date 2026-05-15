import 'package:empresa_server/fechamentos_util.dart';
import 'package:test/test.dart';

void main() {
  group('calcularProximaDataFechamento', () {
    test('semanal — alvo é depois de hoje na mesma semana', () {
      // 2026-05-04 (segunda). Sexta = dia 5 → +4 dias.
      final result = calcularProximaDataFechamento('semanal', 5, DateTime(2026, 5, 4));
      expect(result, '2026-05-08');
    });

    test('semanal — alvo é o mesmo dia → +7 dias', () {
      // 2026-05-04 (segunda). Alvo segunda (1) → +7 = 2026-05-11
      final result = calcularProximaDataFechamento('semanal', 1, DateTime(2026, 5, 4));
      expect(result, '2026-05-11');
    });

    test('semanal — alvo já passou → +N dias até próxima semana', () {
      // Quinta 2026-05-07. Alvo terça (2) → próxima terça = 2026-05-12
      final result = calcularProximaDataFechamento('semanal', 2, DateTime(2026, 5, 7));
      expect(result, '2026-05-12');
    });

    test('quinzenal — antes do dia 15 → dia 15 do mesmo mês', () {
      final result = calcularProximaDataFechamento('quinzenal', null, DateTime(2026, 5, 10));
      expect(result, '2026-05-15');
    });

    test('quinzenal — depois do 15 → último dia do mês', () {
      final result = calcularProximaDataFechamento('quinzenal', null, DateTime(2026, 5, 20));
      expect(result, '2026-05-31');
    });

    test('mensal — antes do dia → mesmo mês', () {
      final result = calcularProximaDataFechamento('mensal', 20, DateTime(2026, 5, 10));
      expect(result, '2026-05-20');
    });

    test('mensal — depois do dia → próximo mês (C-05)', () {
      final result = calcularProximaDataFechamento('mensal', 5, DateTime(2026, 5, 10));
      expect(result, '2026-06-05');
    });

    test('mensal dia 31 em fevereiro → último dia de fevereiro', () {
      final result = calcularProximaDataFechamento('mensal', 31, DateTime(2026, 1, 31));
      // 2026 não é bissexto → 28/02
      expect(result, '2026-02-28');
    });

    test('mensal cruza ano (dia 5 em dezembro → janeiro próximo)', () {
      final result = calcularProximaDataFechamento('mensal', 5, DateTime(2026, 12, 10));
      expect(result, '2027-01-05');
    });

    test('data_fixa (legado) trata como mensal — não loopa (C-05)', () {
      // Mesmo input que loopava antes; agora vira mensal usando o dia.
      final result = calcularProximaDataFechamento('data_fixa', 15, DateTime(2026, 5, 10));
      expect(result, '2026-05-15');
    });
  });
}
