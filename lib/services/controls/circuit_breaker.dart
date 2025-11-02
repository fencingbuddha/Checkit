class CircuitBreaker {
  CircuitBreaker({
    required Duration cooldown,
    this.failureThreshold = 3,
  }) : _cooldown = cooldown;

  final Duration _cooldown;
  final int failureThreshold;

  int _consecutiveFailures = 0;
  DateTime? _openUntil;

  bool get isOpen {
    final openUntil = _openUntil;
    if (openUntil == null) return false;
    if (DateTime.now().isBefore(openUntil)) {
      return true;
    }
    _openUntil = null;
    _consecutiveFailures = 0;
    return false;
  }

  bool allowRequest() => !isOpen;

  void recordSuccess() {
    _consecutiveFailures = 0;
    _openUntil = null;
  }

  void recordFailure() {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= failureThreshold) {
      _openUntil = DateTime.now().add(_cooldown);
      _consecutiveFailures = 0;
    }
  }
}
