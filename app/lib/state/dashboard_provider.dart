import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/dashboard.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.dashboardStats();
});
