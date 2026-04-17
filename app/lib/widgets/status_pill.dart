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
  return switch (status) {
    'pendente' => StatusInfo(
        bg: dark ? const Color(0xFF3D2E00) : const Color(0xFFFFF3E0),
        fg: dark ? const Color(0xFFFFB74D) : const Color(0xFFE67E00),
        label: 'Pendente',
        icon: Icons.schedule_outlined,
      ),
    'agendado' => StatusInfo(
        bg: dark ? const Color(0xFF0D2137) : const Color(0xFFE3F2FD),
        fg: dark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2),
        label: 'Agendado',
        icon: Icons.event_outlined,
      ),
    'producao' => StatusInfo(
        bg: dark ? const Color(0xFF2D1530) : const Color(0xFFF3E5F5),
        fg: dark ? const Color(0xFFCE93D8) : const Color(0xFF8E24AA),
        label: 'Em produção',
        icon: Icons.precision_manufacturing_outlined,
      ),
    'concluido' => StatusInfo(
        bg: dark ? const Color(0xFF0D3318) : const Color(0xFFE8F5E9),
        fg: dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
        label: 'Concluído',
        icon: Icons.check_circle_outline,
      ),
    'entregue' => StatusInfo(
        bg: dark ? const Color(0xFF003D2A) : const Color(0xFFDFF5EC),
        fg: dark ? const Color(0xFF66D5AE) : const Color(0xFF00796B),
        label: 'Entregue',
        icon: Icons.local_shipping_outlined,
      ),
    _ => StatusInfo(
        bg: dark ? const Color(0xFF3A3A38) : const Color(0xFFE0E0DD),
        fg: dark ? Colors.grey.shade400 : Colors.grey.shade700,
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
          dark ? const Color(0xFF0D3318) : const Color(0xFFE8F5E9),
          dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
          'Pago',
          Icons.check_circle,
        ),
      'parcial' => (
          dark ? const Color(0xFF3D2E00) : const Color(0xFFFFF8E1),
          dark ? const Color(0xFFFFCA28) : const Color(0xFFF57F17),
          'Parcial',
          Icons.pending,
        ),
      _ => (
          dark ? const Color(0xFF3D0E0E) : const Color(0xFFFFEBEE),
          dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
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
