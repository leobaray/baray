import 'package:flutter/material.dart';

class StatusInfo {
  final Color bg;
  final Color fg;
  final String label;
  final IconData icon;
  const StatusInfo({required this.bg, required this.fg, required this.label, required this.icon});
}

StatusInfo statusInfo(BuildContext context, String status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  // Paleta sossegada: tons dessaturados, fundo com ~8% de saturação.
  // Mantém clareza de leitura sem gritar.
  return switch (status) {
    'pendente' => StatusInfo(
        bg: dark ? const Color(0xFF2B2419) : const Color(0xFFF5EDE0),
        fg: dark ? const Color(0xFFDEB887) : const Color(0xFF8B6914),
        label: 'Pendente',
        icon: Icons.schedule_outlined,
      ),
    'agendado' => StatusInfo(
        bg: dark ? const Color(0xFF1B2838) : const Color(0xFFEAF0F7),
        fg: dark ? const Color(0xFF89B4D6) : const Color(0xFF3D5A80),
        label: 'Agendado',
        icon: Icons.event_outlined,
      ),
    'producao' => StatusInfo(
        bg: dark ? const Color(0xFF1E2E3E) : const Color(0xFFE3EEF5),
        fg: dark ? const Color(0xFF7FB3CC) : const Color(0xFF2F6486),
        label: 'Em produção',
        icon: Icons.precision_manufacturing_outlined,
      ),
    'concluido' => StatusInfo(
        bg: dark ? const Color(0xFF1C2E22) : const Color(0xFFE6F1E9),
        fg: dark ? const Color(0xFF9CBFA3) : const Color(0xFF446B4E),
        label: 'Concluído',
        icon: Icons.check_circle_outline,
      ),
    'entregue' => StatusInfo(
        bg: dark ? const Color(0xFF0F2E28) : const Color(0xFFDFEFE9),
        fg: dark ? const Color(0xFF7FBFAF) : const Color(0xFF2E6B5C),
        label: 'Entregue',
        icon: Icons.local_shipping_outlined,
      ),
    _ => StatusInfo(
        bg: dark ? const Color(0xFF2C2C2A) : const Color(0xFFEEEEE9),
        fg: dark ? const Color(0xFFAAAAA3) : const Color(0xFF6B6B63),
        label: status,
        icon: Icons.circle_outlined,
      ),
  };
}

class StatusPill extends StatelessWidget {
  final String status;
  final bool small;
  const StatusPill({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final info = statusInfo(context, status);
    return _Pill(bg: info.bg, fg: info.fg, icon: info.icon, label: info.label, small: small);
  }
}

class PagamentoPill extends StatelessWidget {
  final String statusPagamento;
  final bool small;
  const PagamentoPill({super.key, required this.statusPagamento, this.small = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, label, icon) = switch (statusPagamento) {
      'pago' => (
          dark ? const Color(0xFF1C2E22) : const Color(0xFFE6F1E9),
          dark ? const Color(0xFF9CBFA3) : const Color(0xFF446B4E),
          'Pago',
          Icons.check_circle,
        ),
      'parcial' => (
          dark ? const Color(0xFF2B2419) : const Color(0xFFF5EDE0),
          dark ? const Color(0xFFDEB887) : const Color(0xFF8B6914),
          'Parcial',
          Icons.pending,
        ),
      _ => (
          dark ? const Color(0xFF2E1D1D) : const Color(0xFFF5E5E5),
          dark ? const Color(0xFFD99999) : const Color(0xFF8B4444),
          'Devendo',
          Icons.error_outline,
        ),
    };
    return _Pill(bg: bg, fg: fg, icon: icon, label: label, small: small);
  }
}

class _Pill extends StatelessWidget {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  final bool small;

  const _Pill({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.label,
    required this.small,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 4 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 11 : 13, color: fg),
          SizedBox(width: small ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
