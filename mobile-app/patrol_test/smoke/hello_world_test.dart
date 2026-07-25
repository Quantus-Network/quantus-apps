import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('hello world shows Quantus Patrol title', ($) async {
    await $.pumpWidgetAndSettle(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Quantus Patrol')),
        ),
      ),
    );

    expect($('Quantus Patrol'), findsOneWidget);
  });
}
