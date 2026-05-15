/// Helpers para uso seguro do operador `LIKE` do SQLite com termos vindos do
/// usuário.
///
/// [B-04] Antes deste módulo as rotas faziam `'%${termo}%'` direto no bind,
/// sem escapar os metacaracteres do LIKE — `%` (zero-ou-mais chars) e `_`
/// (um char). Resultado: buscar por `arq_test` matchava `arq1test`,
/// `arqXtest`, etc. Não é SQL injection (o termo continua sendo parâmetro
/// posicional), só correctness de UX.
///
/// Uso típico:
///
/// ```dart
/// final termo = '%${escapeLikePattern(qp['busca']!)}%';
/// where.add("descricao LIKE ? ESCAPE '\\'");
/// args.add(termo);
/// ```
///
/// O caractere de escape escolhido é a barra invertida (`\`) — mesma convenção
/// do MySQL/PostgreSQL e amplamente documentada. A query SQL precisa declarar
/// `ESCAPE '\'` explicitamente (sem isso o SQLite não desativa o significado
/// especial de `%` e `_`, mesmo que eles venham prefixados).
library;

/// Escapa os metacaracteres do `LIKE` (`%` e `_`) e o próprio caractere de
/// escape (`\`) em [termo].
///
/// A ordem importa: o `\` é escapado **primeiro**, senão a substituição
/// posterior de `%`/`_` por `\%`/`\_` seria, ela mesma, re-escapada.
///
/// Pareie sempre com `LIKE ? ESCAPE '\\'` na cláusula SQL.
String escapeLikePattern(String termo) {
  return termo
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
