import 'package:web/web.dart' as web;

const _privacyTitle = 'Khair Privacy Policy';
const _privacyDescription =
    'Privacy Policy for the Khair application and services.';
const _privacyCanonical = 'https://khair.it.com/privacy';

void setPrivacyPolicyMetadata() {
  web.document.title = _privacyTitle;
  _setMeta('description', _privacyDescription);
  _setMeta('og:title', _privacyTitle, property: true);
  _setMeta('og:description', _privacyDescription, property: true);
  _setMeta('og:url', _privacyCanonical, property: true);
  _setMeta('twitter:title', _privacyTitle, property: true);
  _setMeta('twitter:description', _privacyDescription, property: true);
  _setCanonical(_privacyCanonical);
}

void resetPrivacyPolicyMetadata() {
  web.document.title = 'Khair — Meaningful Events & Community';
  _setMeta(
    'description',
    'Discover meaningful events, join communities, and help organizers bring people together on Khair.',
  );
  _setMeta('og:title', 'Khair — Meaningful Events & Community', property: true);
  _setMeta(
    'og:description',
    'Discover meaningful events, join communities, and help organizers bring people together.',
    property: true,
  );
  _setMeta('og:url', 'https://khair.it.com', property: true);
  _setMeta('twitter:title', 'Khair — Meaningful Events & Community',
      property: true);
  _setMeta(
    'twitter:description',
    'Discover meaningful events and join communities.',
    property: true,
  );
  _setCanonical('https://khair.it.com');
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
