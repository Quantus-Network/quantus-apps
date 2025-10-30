import 'package:flutter/foundation.dart';

@immutable
class OptedInPosition {
  final String address;
  final int position;
  final bool isOptedIn;

  const OptedInPosition({required this.address, required this.position, required this.isOptedIn});

  factory OptedInPosition.fromJson(Map<String, dynamic> json) {
    return OptedInPosition(
      address: json['data']['quan_address'] as String,
      position: json['data']['position'] as int,
      isOptedIn: json['data']['is_opted_in'] as bool,
    );
  }
}
