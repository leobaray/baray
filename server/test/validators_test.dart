import 'package:empresa_server/validators.dart';
import 'package:test/test.dart';

void main() {
  group('validarPedido (criar)', () {
    test('faltando cliente_nome → erro', () {
      expect(
        validarPedido({'descricao': 'x', 'valor': 10}, criar: true),
        contains('cliente_nome'),
      );
    });

    test('faltando descricao → erro', () {
      expect(
        validarPedido({'cliente_nome': 'X', 'valor': 10}, criar: true),
        contains('descricao'),
      );
    });

    test('valor=0 → erro (resolve A-06+A-09)', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 0},
          criar: true,
        ),
        contains('valor'),
      );
    });

    test('valor negativo → erro', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': -5},
          criar: true,
        ),
        contains('valor'),
      );
    });

    test('quantidade=0 → erro', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'quantidade': 0},
          criar: true,
        ),
        contains('quantidade'),
      );
    });

    test('quantidade acima do limite → erro (resolve M-06)', () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'd',
            'valor': 10,
            'quantidade': 100001,
          },
          criar: true,
        ),
        contains('quantidade'),
      );
    });

    test('quantidade no limite (100000) aceita', () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'd',
            'valor': 10,
            'quantidade': 100000,
          },
          criar: true,
        ),
        isNull,
      );
    });

    test('arte_cores=11 → erro (fora do range)', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'arte_cores': 11},
          criar: true,
        ),
        contains('arte_cores'),
      );
    });

    test('status inválido rejeitado', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'status': 'banana'},
          criar: true,
        ),
        contains('status'),
      );
    });

    test("status='entregue' rejeitado na criação (resolve M-04)", () {
      // Cenário do finding: cliente cria pedido já com status='entregue'
      // → estado fantasma (entregue sem entregue_em). Fluxo correto é via
      // POST /pedidos/<id>/saida que setea entregue_em atomicamente.
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'status': 'entregue'},
          criar: true,
        ),
        contains('status'),
      );
    });

    test("status='concluido' rejeitado na criação (resolve M-04)", () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'status': 'concluido'},
          criar: true,
        ),
        contains('status'),
      );
    });

    test("status='producao' rejeitado na criação (resolve M-04)", () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'status': 'producao'},
          criar: true,
        ),
        contains('status'),
      );
    });

    test("status='pendente' aceito na criação", () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'status': 'pendente'},
          criar: true,
        ),
        isNull,
      );
    });

    test("status='agendado' aceito na criação", () {
      // Agendado é válido na criação porque o agendador interno seta esse
      // status logo após o INSERT (bypassa o validator via UPDATE direto).
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'status': 'agendado'},
          criar: true,
        ),
        isNull,
      );
    });

    test('valor_pago no body → erro (resolve C-03)', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'valor_pago': 5},
          criar: true,
        ),
        contains('valor_pago'),
      );
    });

    test("forma_entrega='retirada' aceito (UI envia substantivo — resolve C-01)", () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'd',
            'valor': 10,
            'forma_entrega': 'retirada',
          },
          criar: true,
        ),
        isNull,
      );
    });

    test("forma_entrega='entrega' aceito (UI envia substantivo — resolve C-01)", () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'd',
            'valor': 10,
            'forma_entrega': 'entrega',
          },
          criar: true,
        ),
        isNull,
      );
    });

    test("forma_entrega='retirar' continua aceito (compat com dados legados)", () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'd',
            'valor': 10,
            'forma_entrega': 'retirar',
          },
          criar: true,
        ),
        isNull,
      );
    });

    test('forma_entrega inválido rejeitado', () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'd',
            'valor': 10,
            'forma_entrega': 'banana',
          },
          criar: true,
        ),
        contains('forma_entrega'),
      );
    });

    test('payload válido completo passa', () {
      expect(
        validarPedido(
          {
            'cliente_nome': 'X',
            'descricao': 'desc',
            'valor': 100.0,
            'quantidade': 12,
            'arte_cores': 3,
            'status': 'pendente',
            'status_pagamento': 'devendo',
            'forma_pagamento': 'pix',
            'regiao': 'FRENTE/COSTAS',
            'tipo_peca': 'camiseta',
          },
          criar: true,
        ),
        isNull,
      );
    });
  });

  group('validarPedido (atualizar)', () {
    test('PUT vazio passa', () {
      expect(validarPedido({}, criar: false), isNull);
    });

    test('PUT com valor=0 falha', () {
      expect(validarPedido({'valor': 0}, criar: false), contains('valor'));
    });

    test('PUT sem mudança de status passa mesmo com statusAtual fornecido', () {
      expect(
        validarPedido({'valor': 50}, criar: false, statusAtual: 'producao'),
        isNull,
      );
    });

    test('PUT com status igual ao atual (no-op) passa', () {
      expect(
        validarPedido(
          {'status': 'producao'},
          criar: false,
          statusAtual: 'producao',
        ),
        isNull,
      );
    });

    test('transição pendente→agendado aceita', () {
      expect(
        validarPedido(
          {'status': 'agendado'},
          criar: false,
          statusAtual: 'pendente',
        ),
        isNull,
      );
    });

    test('transição pendente→producao aceita', () {
      expect(
        validarPedido(
          {'status': 'producao'},
          criar: false,
          statusAtual: 'pendente',
        ),
        isNull,
      );
    });

    test('transição agendado→producao aceita', () {
      expect(
        validarPedido(
          {'status': 'producao'},
          criar: false,
          statusAtual: 'agendado',
        ),
        isNull,
      );
    });

    test('transição producao→concluido aceita', () {
      expect(
        validarPedido(
          {'status': 'concluido'},
          criar: false,
          statusAtual: 'producao',
        ),
        isNull,
      );
    });

    test('transição concluido→pendente rejeitada (M-04)', () {
      // Backward jump não-trivial: concluído já passou pela produção, voltar
      // a pendente perde estado. Se precisar, refaça o pedido.
      expect(
        validarPedido(
          {'status': 'pendente'},
          criar: false,
          statusAtual: 'concluido',
        ),
        contains('transição'),
      );
    });

    test('transição entregue→qualquer rejeitada (terminal)', () {
      // Entregue é terminal: pedido entregue não pode voltar pra fluxo.
      expect(
        validarPedido(
          {'status': 'producao'},
          criar: false,
          statusAtual: 'entregue',
        ),
        contains('transição'),
      );
    });

    test('transição pendente→entregue rejeitada (deve ir via /saida)', () {
      // Pular direto pra entregue cria estado fantasma — entregue_em não
      // é setado via PUT. Fluxo correto: POST /pedidos/<id>/saida.
      expect(
        validarPedido(
          {'status': 'entregue'},
          criar: false,
          statusAtual: 'pendente',
        ),
        contains('transição'),
      );
    });
  });

  group('validarCliente', () {
    test('nome vazio → erro na criação', () {
      expect(validarCliente({}, criar: true), contains('nome'));
    });

    test('fechamento_tipo inválido rejeitado', () {
      expect(
        validarCliente(
          {'nome': 'X', 'fechamento_tipo': 'banana'},
          criar: true,
        ),
        contains('fechamento_tipo'),
      );
    });

    test('fechamento_dia=32 para mensal rejeitado', () {
      expect(
        validarCliente(
          {'nome': 'X', 'fechamento_tipo': 'mensal', 'fechamento_dia': 32},
          criar: true,
        ),
        contains('fechamento_dia'),
      );
    });

    test('fechamento_dia=8 para semanal rejeitado', () {
      expect(
        validarCliente(
          {'nome': 'X', 'fechamento_tipo': 'semanal', 'fechamento_dia': 8},
          criar: true,
        ),
        contains('fechamento_dia'),
      );
    });
  });
}
