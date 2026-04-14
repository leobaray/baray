import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/agenda/agenda_screen.dart';
import 'screens/clientes/cliente_detalhe_screen.dart';
import 'screens/clientes/cliente_form_screen.dart';
import 'screens/clientes/clientes_screen.dart';
import 'screens/clientes/fechamento_detalhe_screen.dart';
import 'screens/configuracoes/configuracoes_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/home_shell.dart';
import 'screens/kanban/kanban_screen.dart';
import 'screens/orcamento/orcamento_screen.dart';
import 'screens/pedidos/pedido_detalhe_screen.dart';
import 'screens/pedidos/pedido_form_screen.dart';
import 'screens/pedidos/pedidos_screen.dart';

CustomTransitionPage<T> _fadeSlidePage<T>({
  required Widget child,
  required String name,
}) {
  return CustomTransitionPage<T>(
    name: name,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (c, s) => _fadeSlidePage(child: const DashboardScreen(), name: 'dashboard'),
        ),
        GoRoute(
          path: '/pedidos',
          pageBuilder: (c, s) => _fadeSlidePage(child: const PedidosScreen(), name: 'pedidos'),
        ),
        GoRoute(
          path: '/agenda',
          pageBuilder: (c, s) => _fadeSlidePage(child: const AgendaScreen(), name: 'agenda'),
        ),
        GoRoute(
          path: '/clientes',
          pageBuilder: (c, s) => _fadeSlidePage(child: const ClientesScreen(), name: 'clientes'),
        ),
        GoRoute(
          path: '/configuracoes',
          pageBuilder: (c, s) => _fadeSlidePage(child: const ConfiguracoesScreen(), name: 'configuracoes'),
        ),
      ],
    ),
    GoRoute(
      path: '/kanban',
      pageBuilder: (c, s) => _fadeSlidePage(child: const KanbanScreen(), name: 'kanban'),
    ),
    GoRoute(
      path: '/orcamento',
      pageBuilder: (c, s) => _fadeSlidePage(child: const OrcamentoScreen(), name: 'orcamento'),
    ),
    GoRoute(
      path: '/pedidos/novo',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: PedidoFormScreen(clienteIdInicial: s.uri.queryParameters['cliente_id']),
        name: 'novo-pedido',
      ),
    ),
    GoRoute(
      path: '/pedidos/:id',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: PedidoDetalheScreen(pedidoId: s.pathParameters['id']!),
        name: 'pedido-detalhe',
      ),
    ),
    GoRoute(
      path: '/pedidos/:id/editar',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: PedidoFormScreen(pedidoId: s.pathParameters['id']),
        name: 'editar-pedido',
      ),
    ),
    GoRoute(
      path: '/clientes/novo',
      pageBuilder: (c, s) => _fadeSlidePage(child: const ClienteFormScreen(), name: 'novo-cliente'),
    ),
    GoRoute(
      path: '/clientes/:id',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: ClienteDetalheScreen(clienteId: s.pathParameters['id']!),
        name: 'cliente-detalhe',
      ),
    ),
    GoRoute(
      path: '/clientes/:id/editar',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: ClienteFormScreen(clienteId: s.pathParameters['id']),
        name: 'editar-cliente',
      ),
    ),
    GoRoute(
      path: '/clientes/:clienteId/fechamentos/:fechamentoId',
      pageBuilder: (c, s) => _fadeSlidePage(
        child: FechamentoDetalheScreen(
          clienteId: s.pathParameters['clienteId']!,
          fechamentoId: s.pathParameters['fechamentoId']!,
        ),
        name: 'fechamento-detalhe',
      ),
    ),
  ],
);