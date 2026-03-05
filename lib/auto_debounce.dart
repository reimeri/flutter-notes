import 'dart:async';

class AutoDebouncer {
  final Duration delay;
  Timer? _timer;

  AutoDebouncer({this.delay = const Duration(milliseconds: 500)});

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
