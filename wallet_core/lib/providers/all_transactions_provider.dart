import 'package:flutter_riverpod/legacy.dart';
import 'package:wallet_core/models/pagination_state.dart';
import 'package:wallet_core/providers/controllers/unified_pagination_controller.dart';

final paginationControllerProvider = StateNotifierProvider<UnifiedPaginationController, PaginationState>(
  (ref) => UnifiedPaginationController(ref),
);
