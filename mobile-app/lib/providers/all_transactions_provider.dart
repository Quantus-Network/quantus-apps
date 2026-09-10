import 'package:flutter_riverpod/legacy.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';

final paginationControllerProvider = StateNotifierProvider<UnifiedPaginationController, PaginationState>(
  (ref) => UnifiedPaginationController(ref),
);
