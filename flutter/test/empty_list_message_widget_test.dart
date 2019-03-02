import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:delern_flutter/views/helpers/empty_list_message_widget.dart';

void main() {
  testWidgets('This takes a display text to show', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: const EmptyListMessageWidget('Message Widget Test...')));

    final messageFinder = find.text('Message Widget Test...');

    expect(messageFinder, findsOneWidget);
  });
}
