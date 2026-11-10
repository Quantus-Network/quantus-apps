import 'package:flutter_riverpod/misc.dart';

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);
