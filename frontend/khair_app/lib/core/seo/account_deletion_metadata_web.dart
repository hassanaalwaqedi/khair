import 'package:web/web.dart' as web;

const _title = 'Khair Account Deletion';
const _description =
    'How to permanently delete your Khair account and associated data.';
const _canonical = 'https://khair-it-app.web.app/account-deletion';

void setAccountDeletionMetadata() {
  web.document.title = _title;
  _setMeta('description', _description);
  _setMeta('og:title', _title, property: true);
  _setMeta('og:description', _description, property: true);
  _setMeta('og:url', _canonical, property: true);
  _setMeta('twitter:title', _title, property: true);
  _setMeta('twitter:description', _description, property: true);
  _setCanonical(_canonical);
}

void resetAccountDeletionMetadata() {
  const title = 'Khair — Meaningful Events & Community';
  const description =
      'Discover meaningful events, join communities, and help organizers bring people together on Khair.';
  web.document.title = title;
  _setMeta('description', description);
  _setMeta('og:title', title, property: true);
  _setMeta('og:description', description, property: true);
  _setMeta('og:url', 'https://khair-it-app.web.app', property: true);
  _setMeta('twitter:title', title, property: true);
  _setMeta('twitter:description', description, property: true);
  _setCanonical('https://khair-it-app.web.app');
}

void _setMeta(String key, String value, {bool property = false}) {
  final attribute = property ? 'property' : 'name';
  final selector = 'meta[$attribute="$key"]';
  final existing = web.document.querySelector(selector);
  final element = existing ?? web.document.createElement('meta');
  element.setAttribute(attribute, key);
  element.setAttribute('content', value);
  if (existing == null) web.document.head?.appendChild(element);
}

void _setCanonical(String href) {
  final existing = web.document.querySelector('link[rel="canonical"]');
  final element = existing ?? web.document.createElement('link');
  element.setAttribute('rel', 'canonical');
  element.setAttribute('href', href);
  if (existing == null) web.document.head?.appendChild(element);
}
