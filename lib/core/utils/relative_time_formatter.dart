class RelativeTimeFormatter {
  const RelativeTimeFormatter._();

  static String format(DateTime time, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) {
      final seconds = diff.inSeconds.clamp(0, 59);
      return '${seconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}
