import 'package:along/features/pairing/presentation/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('incoming invitation shows only the join path', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PairingScreen(incomingToken: 'private-token')),
      ),
    );

    expect(find.text('Join your person.'), findsOneWidget);
    expect(find.text('Join private space'), findsOneWidget);
    expect(find.text('Create and share invitation'), findsNothing);
    expect(find.text('Private link or token'), findsNothing);
  });
}
