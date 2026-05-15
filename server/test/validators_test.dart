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

    test('valor_pago no body → erro (resolve C-03)', () {
      expect(
        validarPedido(
          {'cliente_nome': 'X', 'descricao': 'd', 'valor': 10, 'valor_pago': 5},
          criar: true,
        ),
        contains('valor_pago'),
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
