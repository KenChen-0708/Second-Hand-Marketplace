import '../../models/models.dart';

class PresenceHelper {
  static const Duration onlineGracePeriod = Duration(seconds: 35);

  static bool isUserOnline(UserModel user, {DateTime? now}) {
    if (!user.isOnline) {
      return false;
    }

    final lastSeen = user.lastSeenAt;
    if (lastSeen == null) {
      return true;
    }

    final currentTime = (now ?? DateTime.now()).toUtc();
    return currentTime.difference(lastSeen.toUtc()) <= onlineGracePeriod;
  }

  static String buildPresenceText(
    UserModel user, {
    DateTime? now,
    String onlineText = 'Online',
    String offlineText = 'Offline',
  }) {
    if (isUserOnline(user, now: now)) {
      return onlineText;
    }

    final lastSeen = user.lastSeenAt;
    if (lastSeen == null) {
      return offlineText;
    }

    final difference = (now ?? DateTime.now()).toUtc().difference(lastSeen.toUtc());
    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    }
    if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return 'Last seen ${difference.inDays}d ago';
    }

    final localLastSeen = lastSeen.toLocal();
    return 'Last seen ${localLastSeen.day}/${localLastSeen.month}/${localLastSeen.year}';
  }
}
