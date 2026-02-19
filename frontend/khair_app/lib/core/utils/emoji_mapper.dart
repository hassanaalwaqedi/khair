/// Centralized emoji constants and mapping for the Khair app.
/// All UI emojis should be referenced from here — no inline hardcoding.

const String locationEmoji = '📍';
const String dateEmoji = '📅';
const String attendeesEmoji = '👥';
const String trendingEmoji = '🔥';
const String emptyEmoji = '😔';
const String successEmoji = '✅';
const String pendingEmoji = '⏳';
const String rejectedEmoji = '❌';
const String rocketEmoji = '🚀';

/// Returns the emoji for a given event category/type.
String getCategoryEmoji(String category) {
  switch (category.toLowerCase()) {
    case 'tech':
      return '💻';
    case 'business':
      return '💼';
    case 'education':
      return '🎓';
    case 'health':
      return '🩺';
    case 'culture':
      return '🎭';
    case 'religious':
      return '🕌';
    case 'social':
      return '🤝';
    case 'festival':
      return '🎉';
    case 'workshop':
      return '🛠️';
    case 'conference':
      return '🎤';
    case 'seminar':
      return '📚';
    case 'meetup':
      return '☕';
    case 'other':
      return '📌';
    default:
      return '📌';
  }
}

/// Returns a display label with emoji for an event type.
String getCategoryLabel(String category) {
  return '${getCategoryEmoji(category)} ${_capitalize(category)}';
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
