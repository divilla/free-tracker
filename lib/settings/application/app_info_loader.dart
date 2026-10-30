import 'dart:async';

import '../domain/app_info.dart';
import 'app_info_repository.dart';

enum AppInfoPhase { idle, loading, ready, unavailable }

final class AppInfoState {
  const AppInfoState._(this.phase, {this.info, this.failure});
  final AppInfoPhase phase;
  final AppInfo? info;
  final AppInfoFailureCode? failure;
}

/// One metadata read at a time. No ambient platform dependencies or retry loop.
final class AppInfoLoader {
  AppInfoLoader(this._repository);
  final AppInfoRepository _repository;
  final _states = StreamController<AppInfoState>.broadcast();
  AppInfoState _state = const AppInfoState._(AppInfoPhase.idle);
  Future<void>? _pending;
  Future<void>? _closing;
  bool _closed = false;

  AppInfoState get state => _state;
  Stream<AppInfoState> get states => _states.stream;

  Future<void> load() {
    if (_closed || _state.phase == AppInfoPhase.ready) return Future.value();
    return _pending ??= _read();
  }

  Future<void> retry() => load();

  Future<void> _read() async {
    _publish(const AppInfoState._(AppInfoPhase.loading));
    AppInfoResult result;
    try {
      result = await Future.sync(_repository.load);
    } catch (_) {
      result = const AppInfoFailure(AppInfoFailureCode.readFailed);
    }
    _pending = null;
    if (_closed) return;
    _publish(switch (result) {
      AppInfoSuccess(:final info) => AppInfoState._(
        AppInfoPhase.ready,
        info: info,
      ),
      AppInfoFailure(:final code) => AppInfoState._(
        AppInfoPhase.unavailable,
        failure: code,
      ),
    });
  }

  void _publish(AppInfoState state) {
    _state = state;
    _states.add(state);
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _states.close();
  }
}
