import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed loads are removed from the pending cache and can be retried', () async {
    final Cache cache = Cache();
    final Completer<ByteData> firstLoad = Completer<ByteData>();
    final Future<ByteData> pending = cache.putIfAbsent('icon', () => firstLoad.future);

    expect(
      identical(
        pending,
        cache.putIfAbsent('icon', () => throw StateError('duplicate load')),
      ),
      isTrue,
    );

    final Future<void> expectedFailure = expectLater(pending, throwsStateError);
    firstLoad.completeError(StateError('temporarily unavailable'));
    await expectedFailure;

    final ByteData recovered = ByteData(2);
    final ByteData result = await cache.putIfAbsent(
      'icon',
      () => Future<ByteData>.value(recovered),
    );
    expect(identical(result, recovered), isTrue);
    expect(cache.count, 1);
  });

  test('clear prevents pending loads from repopulating stale entries', () async {
    final Cache cache = Cache();
    final Completer<ByteData> oldLoad = Completer<ByteData>();
    final Future<ByteData> oldFuture = cache.putIfAbsent('icon', () => oldLoad.future);

    cache.clear();

    final ByteData replacement = ByteData(3);
    expect(
      identical(
        await cache.putIfAbsent('icon', () => Future<ByteData>.value(replacement)),
        replacement,
      ),
      isTrue,
    );

    oldLoad.complete(ByteData(1));
    await oldFuture;
    expect(cache.count, 1);

    final ByteData cached = await cache.putIfAbsent(
      'icon',
      () => throw StateError('stale load replaced the cache'),
    );
    expect(identical(cached, replacement), isTrue);
  });

  test('evict invalidates in-flight loads as well as completed loads', () async {
    final Cache cache = Cache();
    final Completer<ByteData> oldLoad = Completer<ByteData>();
    final Future<ByteData> oldFuture = cache.putIfAbsent('icon', () => oldLoad.future);

    expect(cache.evict('icon'), isTrue);
    expect(cache.evict('icon'), isFalse);
    oldLoad.complete(ByteData(1));
    await oldFuture;
    expect(cache.count, 0);

    final ByteData fresh = ByteData(2);
    await cache.putIfAbsent('icon', () => Future<ByteData>.value(fresh));
    expect(cache.count, 1);
    expect(cache.evict('icon'), isTrue);
    expect(cache.count, 0);
  });

  test('eviction remains safe if a new load returns the same Future', () async {
    final Cache cache = Cache();
    final Completer<ByteData> shared = Completer<ByteData>();
    final Future<ByteData> first = cache.putIfAbsent('icon', () => shared.future);
    expect(cache.evict('icon'), isTrue);
    final Future<ByteData> second = cache.putIfAbsent('icon', () => shared.future);

    shared.complete(ByteData(1));
    await first;
    await second;
    expect(cache.count, 1);
  });
}
