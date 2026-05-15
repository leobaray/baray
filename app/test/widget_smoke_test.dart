import 'package:baray/widgets/empty_state.dart';
import 'package:baray/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// M-05: smoke tests de widgets self-contained.
//
// EmptyState e KpiCard foram escolhidos porque:
//   - não dependem de Riverpod/Dio/router (zero mocks);
//   - cobrem os 3 padrões visuais mais usados no app (vazio, KPI, ações);
//   - regressões aqui afetariam visualmente quase todas as telas.
//
// Não exaurimos comportamento — só validamos "renderiza sem crash + texto
// chega na tela", que é o contrato mínimo que pegaria uma regressão grossa
// (ex.: API change quebrando todas as telas que usam o widget).

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('M-05: smoke widget — EmptyState', () {
    testWidgets('variante full renderiza título e subtítulo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icons.inbox,
            titulo: 'Nada por aqui',
            subtitulo: 'Crie o primeiro item pra começar',
          ),
        ),
      );
      expect(find.text('Nada por aqui'), findsOneWidget);
      expect(find.text('Crie o primeiro item pra começar'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('variante compact renderiza com CTA tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState.compact(
            icon: Icons.search_off,
            titulo: 'Sem resultados',
            ctaLabel: 'Limpar filtros',
            onCta: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Sem resultados'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue,
          reason: 'callback do CTA precisa disparar no tap');
    });

    testWidgets('variante inline renderiza e responde a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState.inline(
            icon: Icons.event_available,
            titulo: 'Dia livre',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Dia livre'), findsOneWidget);
      await tester.tap(find.text('Dia livre'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('M-05: smoke widget — KpiCard', () {
    testWidgets('renderiza label, valor e hint', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KpiCard(
            icon: Icons.attach_money,
            label: 'Faturado mês',
            valor: r'R$ 12.345',
            hint: '15 pedidos',
          ),
        ),
      );
      expect(find.text('Faturado mês'), findsOneWidget);
      expect(find.text(r'R$ 12.345'), findsOneWidget);
      expect(find.text('15 pedidos'), findsOneWidget);
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });

    testWidgets('onTap dispara callback e mostra seta', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          KpiCard(
            icon: Icons.pending,
            label: 'Pendentes',
            valor: '8',
            onTap: () => tapped = true,
          ),
        ),
      );
      // Seta só aparece quando há onTap.
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('sem onTap, sem seta de navegação', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KpiCard(
            icon: Icons.bar_chart,
            label: 'Total',
            valor: '100',
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });
}
