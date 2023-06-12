// import 'dart:async';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';

// // ignore_for_file: non_constant_identifier_names
// // ignore_for_file: camel_case_types
// // ignore_for_file: prefer_single_quotes

// // This file is automatically generated. DO NOT EDIT, all your changes would be lost.
// class S implements WidgetsLocalizations {
//   const S();

//   static S current;

//   static const GeneratedLocalizationsDelegate delegate =
//       GeneratedLocalizationsDelegate();

//   static S of(BuildContext context) => Localizations.of<S>(context, S);

//   @override
//   TextDirection get textDirection => TextDirection.ltr;
// }

// class $en extends S {
//   const $en();
// }

// class GeneratedLocalizationsDelegate extends LocalizationsDelegate<S> {
//   const GeneratedLocalizationsDelegate();

//   List<Locale> get supportedLocales {
//     return const <Locale>[
//       Locale('en', ''),
//     ];
//   }

//   LocaleListResolutionCallback listResolution(
//       {Locale fallback, bool withCountry = true}) {
//     return (List<Locale> locales, Iterable<Locale> supported) {
//       if (locales == null || locales.isEmpty) {
//         return fallback ?? supported.first;
//       } else {
//         return _resolve(locales.first, fallback, supported, withCountry);
//       }
//     };
//   }

//   LocaleResolutionCallback resolution(
//       {Locale fallback, bool withCountry = true}) {
//     return (Locale locale, Iterable<Locale> supported) {
//       return _resolve(locale, fallback, supported, withCountry);
//     };
//   }

//   @override
//   Future<S> load(Locale locale) {
//     final String lang = getLang(locale);
//     if (lang != null) {
//       switch (lang) {
//         case 'en':
//           S.current = const $en();
//           return SynchronousFuture<S>(S.current);
//         default:
//         // NO-OP.
//       }
//     }
//     S.current = const S();
//     return SynchronousFuture<S>(S.current);
//   }

//   @override
//   bool isSupported(Locale locale) => _isSupported(locale, true);

//   @override
//   bool shouldReload(GeneratedLocalizationsDelegate old) => false;

//   ///
//   /// Internal method to resolve a locale from a list of locales.
//   ///
//   Locale _resolve(Locale locale, Locale fallback, Iterable<Locale> supported,
//       bool withCountry) {
//     if (locale == null || !_isSupported(locale, withCountry)) {
//       return fallback ?? supported.first;
//     }

//     final Locale languageLocale = Locale(locale.languageCode, '');
//     if (supported.contains(locale)) {
//       return locale;
//     } else if (supported.contains(languageLocale)) {
//       return languageLocale;
//     } else {
//       final Locale fallbackLocale = fallback ?? supported.first;
//       return fallbackLocale;
//     }
//   }

//   ///
//   /// Returns true if the specified locale is supported, false otherwise.
//   ///
//   bool _isSupported(Locale locale, bool withCountry) {
//     if (locale != null) {
//       for (Locale supportedLocale in supportedLocales) {
//         // Language must always match both locales.
//         if (supportedLocale.languageCode != locale.languageCode) {
//           continue;
//         }

//         // If country code matches, return this locale.
//         if (supportedLocale.countryCode == locale.countryCode) {
//           return true;
//         }

//         // If no country requirement is requested, check if this locale has no country.
//         if (true != withCountry &&
//             (supportedLocale.countryCode == null ||
//                 supportedLocale.countryCode.isEmpty)) {
//           return true;
//         }
//       }
//     }
//     return false;
//   }
// }

// String getLang(Locale l) => l == null
//     ? null
//     : l.countryCode != null && l.countryCode.isEmpty
//         ? l.languageCode
//         : l.toString();
