import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Since the page has complex dependencies (AuthBloc, API), we will mock a simpler
// version that perfectly mimics the state machine of the original page to reproduce
// the exact RangeError caused by the concurrency flaw.

class MockOrganizerAccessPage extends StatefulWidget {
  @override
  _MockOrganizerAccessPageState createState() => _MockOrganizerAccessPageState();
}

class _MockOrganizerAccessPageState extends State<MockOrganizerAccessPage> {
  int _step = 0;
  bool _saving = false;
  
  static const _stepTitles = ['Basics', 'Identity', 'Plan', 'Review'];

  Future<bool> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate API call
    if (mounted) setState(() => _saving = false);
    return true;
  }

  Future<void> _continue() async {
    if (!await _save()) return;
    if (!mounted) return;
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Step Title: ${_stepTitles[_step]}'),
          ElevatedButton(
            onPressed: _step == 3 ? () {} : _continue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('Reproduce rapid double tap crash in OrganizerAccessPage', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MockOrganizerAccessPage(),
    ));

    // Force _step to 2 by pressing Continue twice, waiting for each to finish
    for (int i = 0; i < 2; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    
    expect(find.text('Step Title: Plan'), findsOneWidget);

    // Now at Step 2. We double tap 'Continue' rapidly without awaiting pump in between.
    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    
    // We pump to allow the async operations to complete and the widget to rebuild
    await tester.pump(const Duration(milliseconds: 200)); // both async _save calls finish
    
    // The widget rebuilds, and the crash should happen here
    await tester.pumpAndSettle();
  });
}
