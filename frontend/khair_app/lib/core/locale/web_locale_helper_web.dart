import 'dart:html' as html;

void setWebLocale(String lang, String dir) {
  html.document.documentElement?.setAttribute('lang', lang);
  html.document.documentElement?.setAttribute('dir', dir);
}
