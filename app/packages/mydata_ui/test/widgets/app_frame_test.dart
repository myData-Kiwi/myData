import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

const _updated = 'Last updated at 09:12';

const _sections = [
  AppSection(icon: Icons.photo_library_outlined, label: 'Library'),
  AppSection(icon: Icons.photo_album_outlined, label: 'Albums'),
  AppSection(icon: Icons.people_outline_rounded, label: 'People'),
  AppSection(icon: Icons.place_outlined, label: 'Places'),
];

/// A screen inside the frame, as an app would put there.
Widget _page(String title) => PageScaffold(
      title: title,
      actions: [Button(label: 'Add photos', variant: ButtonVariant.filled, onPressed: _noop)],
      children: const [
        MyDataCard(
          icon: Icons.cloud_upload_outlined,
          name: 'Backing up 248 photos',
          child: Text('To the drive on this Mac. You can keep using myPhotos while this finishes.'),
        ),
        MyDataCard(
          icon: Icons.face_outlined,
          name: 'Group photos by face',
          child: Text('Runs on your host.'),
        ),
      ],
    );

Widget _frame(
  double width,
  double height, {
  AppConnection connection = const AppConnection.connected(onOpenMyData: _noop),
  int current = 0,
  ValueChanged<int>? onSelect,
  String appName = 'myPhotos',
  List<AppSection> sections = _sections,
  bool withPage = false,
}) =>
    SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: AppFrame(
          appName: appName,
          sections: sections,
          current: current,
          onSelect: onSelect ?? (_) {},
          connection: connection,
          // Behaviour tests leave the content empty, so the only labels and buttons are the frame's.
          child: withPage ? _page(sections[current].label) : const SizedBox.expand(key: Key('content')),
        ),
      ),
    );

/// A phone frame: the window is phone-sized, so PageScaffold uses the phone title and padding too.
Widget _phone({AppConnection connection = const AppConnection.connected(), int current = 0}) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: const Size(375, 680)),
        child: _frame(375, 680, connection: connection, current: current, withPage: true),
      ),
    );

/// A tablet-width window, so PageScaffold uses the desktop title and padding.
Widget _medium({AppConnection connection = const AppConnection.connected(onOpenMyData: _noop), int current = 0}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: const Size(760, 520)),
        child: _frame(760, 520, connection: connection, current: current, withPage: true),
      ),
    );

Future<void> _pumpFrame(WidgetTester tester, Widget frame, {Size view = const Size(1200, 700)}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, frame, padding: EdgeInsets.zero));
}

void main() {
  goldenMatrix('app_frame_sidebar', () => _frame(1100, 600, withPage: true), size: const Size(1148, 648));

  goldenMatrix(
    'app_frame_sidebar_states',
    () => Column(mainAxisSize: MainAxisSize.min, children: [
      // A retry under way: the disabled button has its reason beside it.
      _frame(1100, 400,
          connection: const AppConnection.unreachable(onRetry: null, lastUpdated: _updated), current: 1, withPage: true),
      const SizedBox(height: MyDataSpace.s6),
      _frame(1100, 400, appName: 'myData', connection: const AppConnection.starting(), current: 2, withPage: true),
    ]),
    size: const Size(1148, 872),
    // The loading kiwi turns forever; still, it settles.
    reduceMotion: true,
  );

  goldenMatrix(
    'app_frame_rail',
    () => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _medium(),
      const SizedBox(width: MyDataSpace.s6),
      _medium(connection: const AppConnection.unreachable(onRetry: _noop, lastUpdated: _updated), current: 2),
    ]),
    size: const Size(1592, 568),
  );

  goldenMatrix(
    'app_frame_phone',
    () => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _phone(),
      const SizedBox(width: MyDataSpace.s6),
      _phone(connection: const AppConnection.unreachable(onRetry: null, lastUpdated: _updated), current: 1),
      const SizedBox(width: MyDataSpace.s6),
      _phone(connection: const AppConnection.starting(), current: 3),
    ]),
    size: const Size(1221, 728),
    reduceMotion: true,
  );

  group('layout', () {
    testWidgets('a section with a count shows the number after its label and is heard with it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpFrame(
        tester,
        _frame(1100, 600, sections: const [
          AppSection(icon: Icons.contacts_outlined, label: 'Contacts'),
          AppSection(icon: Icons.fact_check_outlined, label: 'Review', count: 4),
          AppSection(icon: Icons.delete_outline_rounded, label: 'Deleted', count: 0),
        ]),
      );
      final c = tester.element(find.byType(AppFrame)).colors;
      final count = tester.widget<Text>(find.text('4'));
      expect(count.style!.color, c.inkMuted);
      expect(count.style!.fontSize, MyDataType.caption.fontSize);
      expect(tester.getRect(find.text('4')).left, greaterThan(tester.getRect(find.text('Review')).right));
      expect(find.text('0'), findsNothing);
      expect(find.bySemanticsLabel('Review, 4'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('over 1024px: a sidebar-width sidebar on surface with the app name, rows and connection',
        (tester) async {
      await _pumpFrame(tester, _frame(1025, 600));
      final c = tester.element(find.byType(AppFrame)).colors;
      final name = tester.widget<Text>(find.text('myPhotos'));
      expect(name.style!.fontSize, MyDataType.title.fontSize);
      expect(name.style!.fontFamily, MyDataType.title.fontFamily);
      expect(name.style!.color, c.ink);
      // The sidebar: the surface container that holds the name.
      final sidebar = find.ancestor(of: find.text('myPhotos'), matching: find.byType(Container)).last;
      expect(tester.getSize(sidebar).width, MyDataSize.sidebarWidth);
      expect(tester.widget<Container>(sidebar).color, c.surface);
      // No logo in the frame.
      expect(find.byType(KiwiMark), findsNothing);
      for (final s in _sections) {
        expect(find.text(s.label), findsOneWidget);
      }
      expect(find.text(AppConnection.connectedText), findsOneWidget);
      expect(find.byType(FloatingBar), findsNothing);
      // The content area starts right of the sidebar.
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, MyDataSize.sidebarWidth);
    });

    testWidgets('the current row is an accent-soft pill with accent text; the others are ink-muted', (tester) async {
      await _pumpFrame(tester, _frame(1100, 600, current: 1));
      final c = tester.element(find.byType(AppFrame)).colors;
      expect(tester.widget<Text>(find.text('Albums')).style!.color, c.accent);
      expect(tester.widget<Text>(find.text('Albums')).style!.fontWeight, MyDataType.bodyStrong.fontWeight);
      expect(tester.widget<Text>(find.text('Library')).style!.color, c.inkMuted);
      // The outer one; the inner one is Pressable's hover fill.
      final pill = find.ancestor(of: find.text('Albums'), matching: find.byType(AnimatedContainer)).last;
      final box = tester.widget<AnimatedContainer>(pill).decoration! as BoxDecoration;
      expect(box.color, c.accentSoft);
      expect(box.borderRadius, MyDataRadii.pill);
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(MyDataSize.controlHeight));
    });

    testWidgets('600 to 1024px: a slim rail, no app name, no floating bar', (tester) async {
      for (final w in [600.0, 1024.0]) {
        await _pumpFrame(tester, _frame(w, 600));
        expect(find.text('myPhotos'), findsNothing);
        expect(find.byType(FloatingBar), findsNothing);
        expect(find.text('Library'), findsOneWidget);
        expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, AppFrame.railWidth);
        expect(find.text(AppConnection.connectedShortText), findsOneWidget);
      }
    });

    testWidgets('under 600px: the sections in a floating bar; nothing about the host while connected',
        (tester) async {
      await _pumpFrame(tester, _frame(599, 700), view: const Size(599, 700));
      expect(find.byType(FloatingBar), findsOneWidget);
      expect(tester.widget<FloatingBar>(find.byType(FloatingBar)).current, 0);
      expect(find.text(AppConnection.connectedText), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 0);
      // The app name is the large title at the top of the screen, and the content starts under it.
      final c = tester.element(find.byType(AppFrame)).colors;
      final name = tester.widget<Text>(find.text('myPhotos'));
      expect(name.style!.fontSize, MyDataType.displayXl.fontSize);
      expect(name.style!.fontFamily, MyDataType.displayXl.fontFamily);
      expect(name.style!.color, c.ink);
      expect(tester.getTopLeft(find.text('myPhotos')), const Offset(MyDataSpace.s4, MyDataSpace.s4));
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, tester.getBottomLeft(find.text('myPhotos')).dy);
      expect(tester.getSemantics(find.text('myPhotos')), matchesSemantics(label: 'myPhotos', isHeader: true));
    });

    testWidgets('under 600px the content gets the tab bar clearance in every connection state', (tester) async {
      for (final connection in const [
        AppConnection.connected(),
        AppConnection.starting(),
        AppConnection.unreachable(onRetry: _noop),
      ]) {
        late EdgeInsets padding;
        tester.view.physicalSize = const Size(375, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 375,
            height: 700,
            child: AppFrame(
              appName: 'myPhotos',
              sections: _sections,
              current: 0,
              onSelect: (_) {},
              connection: connection,
              child: Builder(builder: (context) {
                padding = MediaQuery.paddingOf(context);
                return const SizedBox.expand();
              }),
            ),
          ),
          padding: EdgeInsets.zero,
          reduceMotion: true,
        ));
        await tester.pump();
        expect(padding.bottom, greaterThanOrEqualTo(FloatingBar.height + 2 * FloatingBarHost.inset),
            reason: 'the last section must clear the tab bar (${connection.state})');
        expect(padding.top, 0, reason: 'the frame has already kept clear of the top (${connection.state})');
      }
    });

    testWidgets('under 600px the title actions sit at the end of the large title; not from 600px', (tester) async {
      Widget frame(double width) => SizedBox(
            width: width,
            height: 600,
            child: AppFrame(
              appName: 'myContacts',
              sections: _sections,
              current: 0,
              onSelect: (_) {},
              phoneTitleActions: [MyDataIconButton(icon: Icons.add_rounded, label: 'New contact', onPressed: () {})],
              child: const SizedBox.expand(),
            ),
          );
      await _pumpFrame(tester, frame(375), view: const Size(375, 600));
      final button = find.byType(MyDataIconButton);
      expect(button, findsOneWidget);
      expect(tester.getCenter(button).dy, closeTo(tester.getCenter(find.text('myContacts')).dy, 1));
      expect(tester.getTopRight(button).dx, closeTo(375 - MyDataSpace.s4, 1));
      await _pumpFrame(tester, frame(1100), view: const Size(1100, 600));
      expect(find.byType(MyDataIconButton), findsNothing);
    });

    testWidgets('a phone app with one section gets no tab bar', (tester) async {
      await _pumpFrame(tester, _frame(375, 700, sections: const [AppSection(icon: Icons.chat_outlined, label: 'Chat')]),
          view: const Size(375, 700));
      expect(find.byType(FloatingBar), findsNothing);
    });

    testWidgets('one phone breakpoint and the phone body size: 16px under 600px, 15px from it', (tester) async {
      for (final (width, phone) in [(599.0, true), (600.0, false)]) {
        tester.view.physicalSize = Size(width, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        late BuildContext context;
        await tester.pumpWidget(Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }));
        expect(AppLayout.isPhone(context), phone);
        expect(PhoneType.bodyOf(context).fontSize, phone ? PhoneType.bodySize : MyDataType.body.fontSize);
        expect(PhoneType.bodyOf(context, MyDataType.bodyStrong).fontWeight, MyDataType.bodyStrong.fontWeight);
      }
    });

    test('AppLayout breakpoints', () {
      expect(AppLayout.forWidth(375), AppLayout.phone);
      expect(AppLayout.forWidth(599.9), AppLayout.phone);
      expect(AppLayout.forWidth(600), AppLayout.rail);
      expect(AppLayout.forWidth(1024), AppLayout.rail);
      expect(AppLayout.forWidth(1024.5), AppLayout.sidebar);
    });
  });

  group('section selection', () {
    testWidgets('clicking a sidebar row selects it', (tester) async {
      final picked = <int>[];
      await _pumpFrame(tester, _frame(1100, 600, onSelect: picked.add));
      await tester.tap(find.text('People'));
      await tester.tap(find.text('Library'));
      expect(picked, [2, 0]);
    });

    testWidgets('keyboard: Tab reaches the rows, the arrows move between them, Enter and Space select',
        (tester) async {
      final picked = <int>[];
      await _pumpFrame(tester, _frame(1100, 600, onSelect: picked.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      String? focusedLabel() =>
          FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>()?.semanticLabel;
      expect(focusedLabel(), 'Library');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusedLabel(), 'Albums');
      expect(picked, isEmpty, reason: 'the arrows move focus; they do not open a section');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, [1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(focusedLabel(), 'Places', reason: 'the arrows wrap at the ends');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(picked, [1, 3]);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(focusedLabel(), 'Library');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(focusedLabel(), 'Places');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), AppConnection.openMyDataText, reason: 'Tab goes on to the link');
    });

    testWidgets('the rail: click and keyboard', (tester) async {
      final picked = <int>[];
      await _pumpFrame(tester, _frame(800, 600, onSelect: picked.add));
      await tester.tap(find.text('Places'));
      expect(picked, [3]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, [3, 1]);
    });

    testWidgets('the phone tab bar selects', (tester) async {
      final picked = <int>[];
      await _pumpFrame(tester, _frame(375, 700, onSelect: picked.add), view: const Size(375, 700));
      await tester.tap(find.descendant(of: find.byType(FloatingBar), matching: find.text('Albums')));
      expect(picked, [1]);
    });

    testWidgets('semantics: rows are buttons named by their label; the current one is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpFrame(tester, _frame(1100, 600, current: 2));
      expect(
        tester.getSemantics(find.ancestor(of: find.text('People'), matching: find.byType(Pressable)).first),
        matchesSemantics(
          label: 'People',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('connection', () {
    testWidgets('connected: the brand dot and the Open myData link, accent and underlined', (tester) async {
      var opened = 0;
      await _pumpFrame(tester, _frame(1100, 600, connection: AppConnection.connected(onOpenMyData: () => opened++)));
      final c = tester.element(find.byType(AppFrame)).colors;
      final dots = find.byWidgetPredicate((w) =>
          w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == c.brand);
      expect(dots, findsOneWidget);
      final link = tester.widget<Text>(find.text(AppConnection.openMyDataText));
      expect(link.style!.color, c.accent);
      expect(link.style!.decoration, TextDecoration.underline);
      expect(tester.getSize(find.ancestor(of: find.text(AppConnection.openMyDataText), matching: find.byType(Pressable)))
          .height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      await tester.tap(find.text(AppConnection.openMyDataText));
      expect(opened, 1);
    });

    testWidgets('the myData app passes no link', (tester) async {
      await _pumpFrame(tester, _frame(1100, 600, appName: 'myData', connection: const AppConnection.connected()));
      expect(find.text(AppConnection.connectedText), findsOneWidget);
      expect(find.text(AppConnection.openMyDataText), findsNothing);
    });

    testWidgets('unreachable: a warning line and a tonal Retry, in every layout', (tester) async {
      for (final (w, view) in [(1100.0, const Size(1200, 700)), (800.0, const Size(1200, 700)), (375.0, const Size(375, 700))]) {
        var retried = 0;
        await _pumpFrame(tester, _frame(w, 600, connection: AppConnection.unreachable(onRetry: () => retried++)),
            view: view);
        final c = tester.element(find.byType(AppFrame)).colors;
        expect(tester.widget<Text>(find.text(AppConnection.unreachableText)).style!.color, c.warning);
        final retry = tester.widget<Button>(find.widgetWithText(Button, AppConnection.retryText));
        expect(retry.variant, ButtonVariant.tonal);
        await tester.tap(find.text(AppConnection.retryText));
        expect(retried, 1, reason: 'at width $w');
      }
    });

    testWidgets('unreachable with a retry under way: the button is disabled, with the reason next to it',
        (tester) async {
      await _pumpFrame(tester, _frame(1100, 600, connection: const AppConnection.unreachable(onRetry: null)));
      final retry = find.widgetWithText(Button, AppConnection.retryText);
      expect(tester.widget<Button>(retry).onPressed, isNull);
      final reason = find.text(AppConnection.retryingText);
      expect(reason, findsOneWidget);
      final c = tester.element(find.byType(AppFrame)).colors;
      expect(tester.widget<Text>(reason).style!.color, c.inkMuted);
      // Beside the button, on its line.
      expect(tester.getTopLeft(reason).dx, greaterThan(tester.getTopRight(retry).dx));
      expect(tester.getCenter(reason).dy, moreOrLessEquals(tester.getCenter(retry).dy, epsilon: 12));

      // The rail says it in short, with the full sentence as its tooltip and accessible name.
      await _pumpFrame(tester, _frame(800, 600, connection: const AppConnection.unreachable(onRetry: null)));
      expect(tester.widget<Button>(find.widgetWithText(Button, AppConnection.retryText)).onPressed, isNull);
      expect(find.text(AppConnection.retryingShortText), findsOneWidget);
      expect(find.byTooltip(AppConnection.retryingText), findsOneWidget);

      // The phone puts it under the warning line, left of the button.
      await _pumpFrame(tester, _frame(375, 700, connection: const AppConnection.unreachable(onRetry: null)),
          view: const Size(375, 700));
      expect(find.text(AppConnection.retryingText), findsOneWidget);
      expect(tester.getTopRight(find.text(AppConnection.retryingText)).dx,
          lessThan(tester.getTopLeft(find.widgetWithText(Button, AppConnection.retryText)).dx));
    });

    testWidgets('unreachable: when the data was last updated, under the warning line, in every layout',
        (tester) async {
      for (final (w, view) in [(1100.0, const Size(1200, 700)), (800.0, const Size(1200, 700)), (375.0, const Size(375, 700))]) {
        await _pumpFrame(
            tester, _frame(w, 600, connection: const AppConnection.unreachable(onRetry: _noop, lastUpdated: _updated)),
            view: view);
        final c = tester.element(find.byType(AppFrame)).colors;
        final updated = find.text(_updated);
        expect(updated, findsOneWidget, reason: 'at width $w');
        expect(tester.widget<Text>(updated).style!.color, c.inkMuted);
        expect(tester.widget<Text>(updated).style!.fontSize, MyDataType.caption.fontSize);
        expect(tester.getTopLeft(updated).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(find.text(AppConnection.unreachableText)).dy),
            reason: 'under the warning line at width $w');
        expect(find.text(AppConnection.retryingText), findsNothing, reason: 'Retry is ready at width $w');
        expect(find.text(AppConnection.retryingShortText), findsNothing);
      }
      // No time given, no caption.
      await _pumpFrame(tester, _frame(1100, 600, connection: const AppConnection.unreachable(onRetry: _noop)));
      expect(find.textContaining('Last updated'), findsNothing);
    });

    testWidgets('starting: the loading kiwi and a muted line', (tester) async {
      await _pumpFrame(tester, _frame(1100, 600, connection: const AppConnection.starting()));
      expect(find.text(AppConnection.startingText), findsOneWidget);
      expect(find.byType(KiwiLoader), findsOneWidget);
      final c = tester.element(find.byType(AppFrame)).colors;
      expect(tester.widget<Text>(find.text(AppConnection.startingText)).style!.color, c.inkMuted);
    });
  });
}
