import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:khair_app/core/locale/locale_bloc.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('device language resolves Arabic, Turkish, English, then fallback', () {
    expect(
      LocaleBloc.resolveDeviceLocale(const [Locale('ar', 'SA')]),
      const Locale('ar'),
    );
    expect(
      LocaleBloc.resolveDeviceLocale(const [Locale('tr', 'TR')]),
      const Locale('tr'),
    );
    expect(
      LocaleBloc.resolveDeviceLocale(const [Locale('en', 'US')]),
      const Locale('en'),
    );
    expect(
      LocaleBloc.resolveDeviceLocale(const [Locale('fr'), Locale('ar')]),
      const Locale('ar'),
    );
    expect(
      LocaleBloc.resolveDeviceLocale(const [Locale('fr')]),
      const Locale('en'),
    );
  });

  test('saved locale is restored and unsupported locales fall back to English',
      () async {
    SharedPreferences.setMockInitialValues({'app_locale_override_v2': 'ar'});
    final bloc = LocaleBloc();

    final restored = bloc.stream.firstWhere(
      (state) => state.locale.languageCode == 'ar',
    );
    bloc.add(const LoadSavedLocale());
    await restored;
    expect(bloc.state.locale, const Locale('ar'));

    final fallback = bloc.stream.firstWhere(
      (state) => state.locale.languageCode == 'en',
    );
    bloc.add(const ChangeLocale(Locale('fr')));
    await fallback;
    expect(bloc.state.locale, const Locale('en'));
    expect(
      (await SharedPreferences.getInstance())
          .getString('app_locale_override_v2'),
      'en',
    );
    await bloc.close();
  });

  testWidgets('Arabic localization establishes RTL directionality',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(
            AppLocalizations.of(context)!.discoverTitle,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'اكتشف التجمعات المفيدة');
    expect(text.textDirection, TextDirection.rtl);
  });
}
