import 'db.dart';
import 'dinheiro.dart';

/// Calculadora de orçamento — aplica regras das configurações.
class CalculadoraOrcamento {
  final Db db;
  CalculadoraOrcamento(this.db);

  Map<String, Object?> calcular({
    required String tecnica,
    required String regiao,
    required int quantidade,
    int cores = 1,
    bool urgente = false,
    String? tipoPeca,
  }) {
    // AUDIT M-01: a tabela_preco não cobre faixa <12. Sem este guard, qtd<12
    // caía em '12-24' e cobrava o preço da faixa de cima (receita perdida).
    // Defensivo: rejeita com erro estruturado. A regra "mínimo 12" é o
    // contrato implícito da tabela de preços (menor faixa cadastrada é 12-24).
    if (quantidade < 12) {
      return {'erro': 'quantidade mínima é 12 peças'};
    }
    final faixa = _faixa(quantidade);
    final rows = db.raw.select(
      'SELECT * FROM tabela_preco WHERE tecnica=? AND regiao=? AND faixa_qtd=?',
      [tecnica, regiao, faixa],
    );
    if (rows.isEmpty) {
      return {
        'erro': 'Nenhum preço cadastrado para $tecnica / $regiao / $faixa',
      };
    }
    final row = rows.first;
    final precoPrimeira = (row['primeira_cor'] as num).toDouble();
    final precoDemais = (row['demais_cores'] as num).toDouble();

    var porPeca = precoPrimeira + (cores - 1).clamp(0, 10) * precoDemais;

    if (tipoPeca == 'moletom_aberto') {
      final pct = db.configNumber('adicional_moletom_aberto_pct', 20);
      porPeca *= (1 + pct / 100);
    } else if (tipoPeca == 'moletom_fechado') {
      final pct = db.configNumber('adicional_moletom_fechado_pct', 60);
      porPeca *= (1 + pct / 100);
    }

    if (urgente) {
      final pct = db.configNumber('taxa_urgencia_pct', 25);
      porPeca *= (1 + pct / 100);
    }

    final matrizLimite = db.configNumber('matriz_gratis_acima_pcs', 150).toInt();
    final matrizValor = regiao == 'FRENTE/COSTAS'
        ? db.configNumber('matriz_padrao_50x60', 45)
        : db.configNumber('matriz_padrao_40x50', 35);
    final cobrarMatriz = quantidade < matrizLimite;
    final totalMatriz = cobrarMatriz ? matrizValor * cores : 0;

    final subtotal = porPeca * quantidade;
    final total = subtotal + totalMatriz;

    return {
      'tecnica': tecnica,
      'regiao': regiao,
      'faixa_qtd': faixa,
      'quantidade': quantidade,
      'cores': cores,
      'urgente': urgente,
      'tipo_peca': tipoPeca,
      'preco_primeira_cor': precoPrimeira,
      'preco_demais_cores': precoDemais,
      // Bankers rounding (half-even) — ver AUDIT A-04 / dinheiro.dart.
      // Substitui o `toStringAsFixed(2)` que usa half-away-from-zero e
      // tende a inflar somatórios em sequências de arredondamentos.
      'preco_por_peca': arredondarCentavos(porPeca),
      'subtotal': arredondarCentavos(subtotal),
      'matriz_cobrada': cobrarMatriz,
      'valor_matriz': totalMatriz,
      'total': arredondarCentavos(total),
    };
  }

  String _faixa(int qtd) {
    if (qtd < 25) return '12-24';
    if (qtd <= 50) return '25-50';
    if (qtd <= 100) return '51-100';
    return '100+';
  }
}
