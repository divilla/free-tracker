import 'dart:async';

import 'package:test/test.dart';
import 'package:free_tracker/settings/domain/app_info.dart';
import 'package:free_tracker/settings/application/app_info_loader.dart';

import '../../support/fixtures.dart';

void main() {
  const failure = AppInfoFailure(AppInfoFailureCode.readFailed);
  test('S001_T08_idle_loading_ready_order', () async {
    final pending = Completer<AppInfoResult>();
    final loader = AppInfoLoader(Repository(() => pending.future));
    final states = <AppInfoState>[];
    loader.states.listen(states.add);
    expect(loader.state.phase, AppInfoPhase.idle);
    final work = loader.load();
    expect(loader.state.phase, AppInfoPhase.loading);
    final result = success();
    pending.complete(result);
    await work;
    await loader.close();
    expect(states.map((s) => s.phase), [
      AppInfoPhase.loading,
      AppInfoPhase.ready,
    ]);
    expect(states.last.info, same(result.info));
    expect(states.last.failure, isNull);
  });
  test('S001_T09_failure_retry_success_order', () async {
    final pending = Completer<AppInfoResult>();
    final repo = Repository(() => pending.future);
    final loader = AppInfoLoader(repo);
    final states = <AppInfoState>[];
    loader.states.listen(states.add);
    final work = loader.load();
    pending.complete(failure);
    await work;
    expect(loader.state.failure, failure.code);
    expect(loader.state.info, isNull);
    // A fresh repository sequence is tested below; this explicit second read
    // of the same completed failure must still publish loading and failure.
    await loader.retry();
    expect(repo.calls, 2);
    await loader.close();
    expect(states.map((s) => s.phase), [
      AppInfoPhase.loading,
      AppInfoPhase.unavailable,
      AppInfoPhase.loading,
      AppInfoPhase.unavailable,
    ]);
  });
  test('S001_T10_pending_requests_coalesce_and_ready_load_is_noop', () async {
    final pending = Completer<AppInfoResult>();
    final repo = Repository(() => pending.future);
    final loader = AppInfoLoader(repo);
    final first = loader.load();
    expect(loader.load(), same(first));
    expect(loader.retry(), same(first));
    expect(repo.calls, 1);
    pending.complete(success());
    await first;
    await loader.load();
    await loader.retry();
    expect(repo.calls, 1);
    await loader.close();
  });
  test('S001_T11_failed_retry_remains_recoverable', () async {
    var reads = 0;
    final loader = AppInfoLoader(
      Repository(() async => ++reads < 3 ? failure : success()),
    );
    await loader.load();
    await loader.retry();
    expect(reads, 2);
    expect(loader.state.failure, failure.code);
    expect(loader.state.info, isNull);
    await loader.retry();
    expect(reads, 3);
    expect(loader.state.phase, AppInfoPhase.ready);
    expect(loader.state.failure, isNull);
    await loader.close();
  });
  for (final outcome in ['success', 'failure', 'throw']) {
    test(
      'S001_T12_close_is_idempotent_and_ignores_late_completion $outcome',
      () async {
        final pending = Completer<AppInfoResult>();
        final repo = Repository(() => pending.future);
        final loader = AppInfoLoader(repo);
        final states = <AppInfoState>[];
        var done = 0;
        loader.states.listen(states.add, onDone: () => done++);
        final work = loader.load();
        final close = loader.close();
        expect(loader.close(), same(close));
        await close;
        if (outcome == 'throw') {
          pending.completeError(StateError('secret'));
        } else {
          pending.complete(outcome == 'success' ? success() : failure);
        }
        await work;
        await loader.load();
        await loader.retry();
        expect(repo.calls, 1);
        expect(done, 1);
        expect(states.map((s) => s.phase), [AppInfoPhase.loading]);
      },
    );
  }
  for (final sync in [true, false]) {
    test(
      'S001_T30_unexpected_repository_error_is_recoverable sync=$sync',
      () async {
        var calls = 0;
        final loader = AppInfoLoader(
          Repository(() {
            if (++calls > 1) return Future.value(success());
            if (sync) throw StateError('secret');
            return Future.error(StateError('secret'));
          }),
        );
        await loader.load();
        expect(loader.state.failure, AppInfoFailureCode.readFailed);
        expect(loader.state.info, isNull);
        await loader.retry();
        expect(loader.state.phase, AppInfoPhase.ready);
        expect(calls, 2);
        await loader.close();
      },
    );
  }
  test('S001_T09_failure_retry_success_order recovery', () async {
    var calls = 0;
    final states = <AppInfoState>[];
    final loader = AppInfoLoader(
      Repository(() async => ++calls == 1 ? failure : success()),
    );
    loader.states.listen(states.add);
    await loader.load();
    await loader.retry();
    await loader.close();
    expect(states.map((s) => s.phase), [
      AppInfoPhase.loading,
      AppInfoPhase.unavailable,
      AppInfoPhase.loading,
      AppInfoPhase.ready,
    ]);
    expect(states[2].failure, isNull);
    expect(states[2].info, isNull);
  });
}
