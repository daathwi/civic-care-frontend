import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When set, MainScreen (worker portal) switches to this tab index.
final workerTabToSelectProvider = StateProvider<int?>((ref) => null);

/// Current worker tab index. Updated when user selects a tab. Dashboard refetches when this becomes 0.
final workerSelectedTabProvider = StateProvider<int>((ref) => 0);
