import 'db.dart';

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
      'preco_por_peca': double.parse(porPeca.toStringAsFixed(2)),
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'matriz_cobrada': cobrarMatriz,
      'valor_matriz': totalMatriz,
      'total': double.parse(total.toStringAsFixed(2)),
    };
  }

  String _faixa(int qtd) {
    if (qtd < 25) return '12-24';
    if (qtd <= 50) return '25-50';
    if (qtd <= 100) return '51-100';
    return '100+';
  }
}
