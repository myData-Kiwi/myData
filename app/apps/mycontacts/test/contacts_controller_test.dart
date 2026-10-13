import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mydata_core/mydata_core.dart';

import 'fixtures.dart';

ContactsController controller(FakeBackend backend, {DeviceStore? store}) =>
    ContactsController(backend: backend, store: store ?? MemoryDeviceStore(), checkInterval: Duration.zero);

void main() {
  test('reads the contacts once, and again only when a source changes', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.running);
    expect(c.contacts, hasLength(backend.cards.length));
    expect(backend.contactCalls, 1);

    await c.follow(HostPhase.running);
    expect(backend.sourceCalls, 2);
    expect(backend.contactCalls, 1, reason: 'nothing changed');

    backend
      ..revision = '2'
      ..cards = [ava];
    await c.follow(HostPhase.running);
    expect(backend.contactCalls, 2);
    expect(c.entries.map((e) => e.id), ['c-ava']);
    expect(c.selectedId, 'c-ava', reason: 'the open contact was removed: the first one is open instead');
    c.dispose();
  });

  test('asks nothing while the host is not running', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.starting);
    await c.follow(HostPhase.lost);
    expect(backend.sourceCalls, 0);
    c.dispose();
  });

  test('turning every source off empties the list', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.running);
    backend.anyOn = false;
    await c.follow(HostPhase.running);
    expect(c.anySourceOn, isFalse);
    expect(c.entries, isEmpty);
    c.dispose();
  });

  test('a failed check keeps the contacts already shown', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.running);
    backend.failSources = true;
    await c.follow(HostPhase.running);
    expect(c.loadFailed, isFalse);
    expect(c.entries, isNotEmpty);
    c.dispose();
  });

  test('the list entries carry the host\'s letter, caption and photo', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.running);
    final ava = c.entryFor('c-ava')!;
    expect(ava.letter, 'A');
    expect(ava.caption, 'Example Labs');
    expect(ava.photo, isNotNull);
    expect(c.entryFor('c-aaron')!.photo, isNull, reason: 'no photo, nothing to fetch');
    expect(c.entryFor('c-emil')!.letter, 'E');
    expect(c.entryFor('c-phone')!.letter, '#');
    c.dispose();
  });

  test('a link the host does not have yet is missing until a later read of the list brings the contact', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.running);
    c.openLink(OpenContact('c-nina'));
    await pumpEventQueue();
    expect(backend.detailCalls, contains('c-nina'), reason: 'the host is asked before saying it is missing');
    expect(c.missingLinkId, 'c-nina');
    expect(c.selectedId, isNull);

    backend
      ..cards = [...backend.cards, card(id: 'c-nina', name: 'Nina Newcard')]
      ..revision = '2';
    await c.follow(HostPhase.running);
    expect(c.missingLinkId, isNull);
    expect(c.selectedId, 'c-nina');
    c.dispose();
  });

  test('a link answered after the user opened another contact does not take over', () async {
    final backend = FakeBackend();
    final c = controller(backend);
    await c.follow(HostPhase.running);
    backend.cards = [...backend.cards, card(id: 'c-nina', name: 'Nina Newcard')];
    c.openLink(OpenContact('c-nina'));
    c.open('c-ben');
    await pumpEventQueue();
    expect(c.selectedId, 'c-ben');
    expect(c.missingLinkId, isNull);
    c.dispose();
  });
}
