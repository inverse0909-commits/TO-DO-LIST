import 'package:flutter_test/flutter_test.dart';

import 'package:todo_list/main.dart';

void main() {
  testWidgets('renders the to do list dashboard', (WidgetTester tester) async {
    final store = TaskStore();
    await tester.pumpWidget(TodoListApp(store: store));

    expect(find.text('To Do List'), findsOneWidget);
    expect(find.text('Small steps every day\nlead to big results.'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
  });
}