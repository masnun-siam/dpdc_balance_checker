// This tests the NAVIGATOR SEMANTICS that the `isCurrent` guard in
// `turnstile_service.dart`'s `dismissSheet()` relies on, not `solveTurnstile`
// itself — `solveTurnstile` builds a real `WebViewController`, which has no
// test-harness platform implementation and cannot be driven directly here.
// It reproduces the exact guard shape (`ctx.mounted &&
// (ModalRoute.of(ctx)?.isCurrent ?? false)` before `Navigator.of(ctx).pop()`)
// against a real `Navigator`. It will NOT catch that guard being deleted
// from the production function; it only proves the guard, as written, does
// the right thing and that removing `isCurrent` regresses it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mirrors dismissSheet()'s guard exactly.
  void guardedPop(BuildContext ctx) {
    if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) {
      Navigator.of(ctx).pop();
    }
  }

  testWidgets('user-dismissed sheet: root route survives (no black screen)',
      (tester) async {
    late BuildContext sheetContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) {
                    sheetContext = ctx;
                    return const Text('sheet content');
                  },
                );
              },
              child: const Text('root content'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('root content'));
    await tester.pumpAndSettle();
    expect(find.text('sheet content'), findsOneWidget);

    // User dismisses via barrier tap; Route.didPop already fired.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('sheet content'), findsNothing);

    // Late completion callback (the `.then((_) => completeError(...))`
    // microtask) tries to pop again — guard must no-op, not pop the root.
    guardedPop(sheetContext);
    await tester.pumpAndSettle();

    expect(find.text('root content'), findsOneWidget);
  });

  testWidgets('a route above the sheet is not popped in its place',
      (tester) async {
    late BuildContext sheetContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) {
                    sheetContext = ctx;
                    return const Text('sheet content');
                  },
                );
              },
              child: const Text('root content'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('root content'));
    await tester.pumpAndSettle();

    // Something else (e.g. an ErrorDialog) gets pushed above the sheet.
    final navigator = Navigator.of(sheetContext);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('dialog content')),
    );
    await tester.pumpAndSettle();
    expect(find.text('dialog content'), findsOneWidget);

    // Late dismissal fires with the stale sheetContext; guard must not pop
    // the dialog that is now on top.
    guardedPop(sheetContext);
    await tester.pumpAndSettle();

    expect(find.text('dialog content'), findsOneWidget);
    expect(find.text('sheet content'), findsNothing);
  });

  testWidgets('success path: sheet is popped exactly once, root survives',
      (tester) async {
    late BuildContext sheetContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) {
                    sheetContext = ctx;
                    return const Text('sheet content');
                  },
                );
              },
              child: const Text('root content'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('root content'));
    await tester.pumpAndSettle();
    expect(find.text('sheet content'), findsOneWidget);

    guardedPop(sheetContext);
    await tester.pumpAndSettle();

    expect(find.text('sheet content'), findsNothing);
    expect(find.text('root content'), findsOneWidget);
  });
}
