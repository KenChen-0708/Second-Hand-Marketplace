import 'package:intl/intl.dart';

const Duration _malaysiaOffset = Duration(hours: 8);

DateTime malaysiaTime(DateTime? dt) {
  final value = dt ?? DateTime.now();
  final utc = value.isUtc ? value : value.toUtc();
  return utc.add(_malaysiaOffset);
}

String relativeTime(DateTime? dt) {
  if (dt == null) {
    return '';
  }

  final diff = malaysiaTime(DateTime.now()).difference(malaysiaTime(dt));
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String formatChatTime(DateTime? dt) {
  if (dt == null) {
    return '';
  }
  return DateFormat('hh:mm a').format(malaysiaTime(dt));
}

String formatChatDate(DateTime? dt) {
  if (dt == null) {
    return '';
  }
  return DateFormat('dd/MM/yyyy').format(malaysiaTime(dt));
}
