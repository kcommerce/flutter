// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection' show HashMap;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'banner.dart';
import 'basic.dart';
import 'binding.dart';
import 'focus_traversal.dart';
import 'framework.dart';
import 'localizations.dart';
import 'media_query.dart';
import 'navigator.dart';
import 'pages.dart';
import 'performance_overlay.dart';
import 'restoration.dart';
import 'router.dart';
import 'scrollable.dart';
import 'semantics_debugger.dart';
import 'shortcuts.dart';
import 'text.dart';
import 'title.dart';
import 'widget_inspector.dart';

export 'dart:ui' show Locale;

/// The signature of [WidgetsApp.localeListResolutionCallback].
///
/// A [LocaleListResolutionCallback] is responsible for computing the locale of the app's
/// [Localizations] object when the app starts and when user changes the list of
/// locales for the device.
///
/// The [locales] list is the device's preferred locales when the app started, or the
/// device's preferred locales the user selected after the app was started. This list
/// is in order of preference. If this list is null or empty, then Flutter has not yet
/// received the locale information from the platform. The [supportedLocales] parameter
/// is just the value of [WidgetsApp.supportedLocales].
///
/// See also:
///
///  * [LocaleResolutionCallback], which takes only one default locale (instead of a list)
///    and is attempted only after this callback fails or is null. [LocaleListResolutionCallback]
///    is recommended over [LocaleResolutionCallback].
typedef LocaleListResolutionCallback = Locale? Function(List<Locale>? locales, Iterable<Locale> supportedLocales);

/// {@template flutter.widgets.LocaleResolutionCallback}
/// The signature of [WidgetsApp.localeResolutionCallback].
///
/// It is recommended to provide a [LocaleListResolutionCallback] instead of a
/// [LocaleResolutionCallback] when possible, as [LocaleResolutionCallback] only
/// receives a subset of the information provided in [LocaleListResolutionCallback].
///
/// A [LocaleResolutionCallback] is responsible for computing the locale of the app's
/// [Localizations] object when the app starts and when user changes the default
/// locale for the device after [LocaleListResolutionCallback] fails or is not provided.
///
/// This callback is also used if the app is created with a specific locale using
/// the [new WidgetsApp] `locale` parameter.
///
/// The [locale] is either the value of [WidgetsApp.locale], or the device's default
/// locale when the app started, or the device locale the user selected after the app
/// was started. The default locale is the first locale in the list of preferred
/// locales. If [locale] is null, then Flutter has not yet received the locale
/// information from the platform. The [supportedLocales] parameter is just the value of
/// [WidgetsApp.supportedLocales].
///
/// See also:
///
///  * [LocaleListResolutionCallback], which takes a list of preferred locales (instead of one locale).
///    Resolutions by [LocaleListResolutionCallback] take precedence over [LocaleResolutionCallback].
/// {@endtemplate}
typedef LocaleResolutionCallback = Locale? Function(Locale? locale, Iterable<Locale> supportedLocales);

/// The signature of [WidgetsApp.onGenerateTitle].
///
/// Used to generate a value for the app's [Title.title], which the device uses
/// to identify the app for the user. The `context` includes the [WidgetsApp]'s
/// [Localizations] widget so that this method can be used to produce a
/// localized title.
///
/// This function must not return null.
typedef GenerateAppTitle = String Function(BuildContext context);

/// The signature of [WidgetsApp.pageRouteBuilder].
///
/// Creates a [PageRoute] using the given [RouteSettings] and [WidgetBuilder].
typedef PageRouteFactory = PageRoute<T> Function<T>(RouteSettings settings, WidgetBuilder builder);

/// The signature of [WidgetsApp.onGenerateInitialRoutes].
///
/// Creates a series of one or more initial routes.
typedef InitialRouteListFactory = List<Route<dynamic>> Function(String initialRoute);

/// A convenience widget that wraps a number of widgets that are commonly
/// required for an application.
///
/// One of the primary roles that [WidgetsApp] provides is binding the system
/// back button to popping the [Navigator] or quitting the application.
///
/// It is used by both [MaterialApp] and [CupertinoApp] to implement base
/// functionality for an app.
///
/// Find references to many of the widgets that [WidgetsApp] wraps in the "See
/// also" section.
///
/// See also:
///
///  * [CheckedModeBanner], which displays a [Banner] saying "DEBUG" when
///    running in checked mode.
///  * [DefaultTextStyle], the text style to apply to descendant [Text] widgets
///    without an explicit style.
///  * [MediaQuery], which establishes a subtree in which media queries resolve
///    to a [MediaQueryData].
///  * [Localizations], which defines the [Locale] for its `child`.
///  * [Title], a widget that describes this app in the operating system.
///  * [Navigator], a widget that manages a set of child widgets with a stack
///    discipline.
///  * [Overlay], a widget that manages a [Stack] of entries that can be managed
///    independently.
///  * [SemanticsDebugger], a widget that visualizes the semantics for the child.
class WidgetsApp extends StatefulWidget {
  /// Creates a widget that wraps a number of widgets that are commonly
  /// required for an application.
  ///
  /// The boolean arguments, [color], and [navigatorObservers] must not be null.
  ///
  /// Most callers will want to use the [home] or [routes] parameters, or both.
  /// The [home] parameter is a convenience for the following [routes] map:
  ///
  /// ```dart
  /// <String, WidgetBuilder>{ '/': (BuildContext context) => myWidget }
  /// ```
  ///
  /// It is possible to specify both [home] and [routes], but only if [routes] does
  ///  _not_ contain an entry for `'/'`.  Conversely, if [home] is omitted, [routes]
  /// _must_ contain an entry for `'/'`.
  ///
  /// If [home] or [routes] are not null, the routing implementation needs to know how
  /// appropriately build [PageRoute]s. This can be achieved by supplying the
  /// [pageRouteBuilder] parameter.  The [pageRouteBuilder] is used by [MaterialApp]
  /// and [CupertinoApp] to create [MaterialPageRoute]s and [CupertinoPageRoute],
  /// respectively.
  ///
  /// The [builder] parameter is designed to provide the ability to wrap the visible
  /// content of the app in some other widget. It is recommended that you use [home]
  /// rather than [builder] if you intend to only display a single route in your app.
  ///
  /// [WidgetsApp] is also possible to provide a custom implementation of routing via the
  /// [onGenerateRoute] and [onUnknownRoute] parameters. These parameters correspond
  /// to [Navigator.onGenerateRoute] and [Navigator.onUnknownRoute]. If [home], [routes],
  /// and [builder] are null, or if they fail to create a requested route,
  /// [onGenerateRoute] will be invoked.  If that fails, [onUnknownRoute] will be invoked.
  ///
  /// The [pageRouteBuilder] will create a [PageRoute] that wraps newly built routes.
  /// If the [builder] is non-null and the [onGenerateRoute] argument is null, then the
  /// [builder] will not be provided only with the context and the child widget, whereas
  /// the [pageRouteBuilder] will be provided with [RouteSettings]. If [onGenerateRoute]
  /// is not provided, [navigatorKey], [onUnknownRoute], [navigatorObservers], and
  /// [initialRoute] must have their default values, as they will have no effect.
  ///
  /// The `supportedLocales` argument must be a list of one or more elements.
  /// By default supportedLocales is `[const Locale('en', 'US')]`.
  WidgetsApp({ // can't be const because the asserts use methods on Iterable :-(
    Key? key,
    this.navigatorKey,
    this.onGenerateRoute,
    this.onGenerateInitialRoutes,
    this.onUnknownRoute,
    List<NavigatorObserver> this.navigatorObservers = const <NavigatorObserver>[],
    this.initialRoute,
    this.pageRouteBuilder,
    this.home,
    Map<String, WidgetBuilder> this.routes = const <String, WidgetBuilder>{},
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.textStyle,
    required this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowWidgetInspector = false,
    this.debugShowCheckedModeBanner = true,
    this.inspectorSelectButtonBuilder,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
  }) : assert(navigatorObservers != null),
       assert(routes != null),
       assert(
         home == null ||
         onGenerateInitialRoutes == null,
         'If onGenerateInitialRoutes is specified, the home argument will be '
         'redundant.'
       ),
       assert(
         home == null ||
         !routes.containsKey(Navigator.defaultRouteName),
         'If the home property is specified, the routes table '
         'cannot include an entry for "/", since it would be redundant.'
       ),
       assert(
         builder != null ||
         home != null ||
         routes.containsKey(Navigator.defaultRouteName) ||
         onGenerateRoute != null ||
         onUnknownRoute != null,
         'Either the home property must be specified, '
         'or the routes table must include an entry for "/", '
         'or there must be on onGenerateRoute callback specified, '
         'or there must be an onUnknownRoute callback specified, '
         'or the builder property must be specified, '
         'because otherwise there is nothing to fall back on if the '
         'app is started with an intent that specifies an unknown route.'
       ),
       assert(
         (home != null ||
          routes.isNotEmpty ||
          onGenerateRoute != null ||
          onUnknownRoute != null)
         ||
         (builder != null &&
          navigatorKey == null &&
          initialRoute == null &&
          navigatorObservers.isEmpty),
         'If no route is provided using '
         'home, routes, onGenerateRoute, or onUnknownRoute, '
         'a non-null callback for the builder property must be provided, '
         'and the other navigator-related properties, '
         'navigatorKey, initialRoute, and navigatorObservers, '
         'must have their initial values '
         '(null, null, and the empty list, respectively).'
       ),
       assert(
         builder != null ||
         onGenerateRoute != null ||
         pageRouteBuilder != null,
         'If neither builder nor onGenerateRoute are provided, the '
         'pageRouteBuilder must be specified so that the default handler '
         'will know what kind of PageRoute transition to build.'
       ),
       assert(title != null),
       assert(color != null),
       assert(supportedLocales != null && supportedLocales.isNotEmpty),
       assert(showPerformanceOverlay != null),
       assert(checkerboardRasterCacheImages != null),
       assert(checkerboardOffscreenLayers != null),
       assert(showSemanticsDebugger != null),
       assert(debugShowCheckedModeBanner != null),
       assert(debugShowWidgetInspector != null),
       routeInformationProvider = null,
       routeInformationParser = null,
       routerDelegate = null,
       backButtonDispatcher = null,
       super(key: key);

  /// Creates a [WidgetsApp] that uses the [Router] instead of a [Navigator].
  WidgetsApp.router({
    Key? key,
    this.routeInformationProvider,
    required RouteInformationParser<Object> this.routeInformationParser,
    required RouterDelegate<Object> this.routerDelegate,
    BackButtonDispatcher? backButtonDispatcher,
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.textStyle,
    required this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowWidgetInspector = false,
    this.debugShowCheckedModeBanner = true,
    this.inspectorSelectButtonBuilder,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
  }) : assert(
         routeInformationParser != null &&
         routerDelegate != null,
         'The routeInformationParser and routerDelegate cannot be null.'
       ),
       assert(title != null),
       assert(color != null),
       assert(supportedLocales != null && supportedLocales.isNotEmpty),
       assert(showPerformanceOverlay != null),
       assert(checkerboardRasterCacheImages != null),
       assert(checkerboardOffscreenLayers != null),
       assert(showSemanticsDebugger != null),
       assert(debugShowCheckedModeBanner != null),
       assert(debugShowWidgetInspector != null),
       navigatorObservers = null,
       backButtonDispatcher = backButtonDispatcher ?? RootBackButtonDispatcher(),
       navigatorKey = null,
       onGenerateRoute = null,
       pageRouteBuilder = null,
       home = null,
       onGenerateInitialRoutes = null,
       onUnknownRoute = null,
       routes = null,
       initialRoute = null,
       super(key: key);

  /// {@template flutter.widgets.widgetsApp.navigatorKey}
  /// A key to use when building the [Navigator].
  ///
  /// If a [navigatorKey] is specified, the [Navigator] can be directly
  /// manipulated without first obtaining it from a [BuildContext] via
  /// [Navigator.of]: from the [navigatorKey], use the [GlobalKey.currentState]
  /// getter.
  ///
  /// If this is changed, a new [Navigator] will be created, losing all the
  /// application state in the process; in that case, the [navigatorObservers]
  /// must also be changed, since the previous observers will be attached to the
  /// previous navigator.
  ///
  /// The [Navigator] is only built if [onGenerateRoute] is not null; if it is
  /// null, [navigatorKey] must also be null.
  /// {@endtemplate}
  final GlobalKey<NavigatorState>? navigatorKey;

  /// {@template flutter.widgets.widgetsApp.onGenerateRoute}
  /// The route generator callback used when the app is navigated to a
  /// named route.
  ///
  /// If this returns null when building the routes to handle the specified
  /// [initialRoute], then all the routes are discarded and
  /// [Navigator.defaultRouteName] is used instead (`/`). See [initialRoute].
  ///
  /// During normal app operation, the [onGenerateRoute] callback will only be
  /// applied to route names pushed by the application, and so should never
  /// return null.
  ///
  /// This is used if [routes] does not contain the requested route.
  ///
  /// The [Navigator] is only built if routes are provided (either via [home],
  /// [routes], [onGenerateRoute], or [onUnknownRoute]); if they are not,
  /// [builder] must not be null.
  /// {@endtemplate}
  ///
  /// If this property is not set, either the [routes] or [home] properties must
  /// be set, and the [pageRouteBuilder] must also be set so that the
  /// default handler will know what routes and [PageRoute]s to build.
  final RouteFactory? onGenerateRoute;

  /// {@template flutter.widgets.widgetsApp.onGenerateInitialRoutes}
  /// The routes generator callback used for generating initial routes if
  /// [initialRoute] is provided.
  ///
  /// If this property is not set, the underlying
  /// [Navigator.onGenerateInitialRoutes] will default to
  /// [Navigator.defaultGenerateInitialRoutes].
  /// {@endtemplate}
  final InitialRouteListFactory? onGenerateInitialRoutes;

  /// The [PageRoute] generator callback used when the app is navigated to a
  /// named route.
  ///
  /// This callback can be used, for example, to specify that a [MaterialPageRoute]
  /// or a [CupertinoPageRoute] should be used for building page transitions.
  final PageRouteFactory? pageRouteBuilder;

  /// {@template flutter.widgets.widgetsApp.routeInformationParser}
  /// A delegate to parse the route information from the
  /// [routeInformationProvider] into a generic data type to be processed by
  /// the [routerDelegate] at a later stage.
  ///
  /// This object will be used by the underlying [Router].
  ///
  /// The generic type `T` must match the generic type of the [routerDelegate].
  ///
  /// See also:
  ///
  ///  * [Router.routeInformationParser]: which receives this object when this
  ///    widget builds the [Router].
  /// {@endtemplate}
  final RouteInformationParser<Object>? routeInformationParser;

  /// {@template flutter.widgets.widgetsApp.routerDelegate}
  /// A delegate that configures a widget, typically a [Navigator], with
  /// parsed result from the [routeInformationParser].
  ///
  /// This object will be used by the underlying [Router].
  ///
  /// The generic type `T` must match the generic type of the
  /// [routeInformationParser].
  ///
  /// See also:
  ///
  ///  * [Router.routerDelegate]: which receives this object when this widget
  ///    builds the [Router].
  /// {@endtemplate}
  final RouterDelegate<Object>? routerDelegate;

  /// {@template flutter.widgets.widgetsApp.backButtonDispatcher}
  /// A delegate that decide whether to handle the Android back button intent.
  ///
  /// This object will be used by the underlying [Router].
  ///
  /// If this is not provided, the widgets app will create a
  /// [RootBackButtonDispatcher] by default.
  ///
  /// See also:
  ///
  ///  * [Router.backButtonDispatcher]: which receives this object when this
  ///    widget builds the [Router].
  /// {@endtemplate}
  final BackButtonDispatcher? backButtonDispatcher;

  /// {@template flutter.widgets.widgetsApp.routeInformationProvider}
  /// A object that provides route information through the
  /// [RouteInformationProvider.value] and notifies its listener when its value
  /// changes.
  ///
  /// This object will be used by the underlying [Router].
  ///
  /// If this is not provided, the widgets app will create a
  /// [PlatformRouteInformationProvider] with initial route name equal to the
  /// [dart:ui.PlatformDispatcher.defaultRouteName] by default.
  ///
  /// See also:
  ///
  ///  * [Router.routeInformationProvider]: which receives this object when this
  ///    widget builds the [Router].
  /// {@endtemplate}
  final RouteInformationProvider? routeInformationProvider;

  /// {@template flutter.widgets.widgetsApp.home}
  /// The widget for the default route of the app ([Navigator.defaultRouteName],
  /// which is `/`).
  ///
  /// This is the route that is displayed first when the application is started
  /// normally, unless [initialRoute] is specified. It's also the route that's
  /// displayed if the [initialRoute] can't be displayed.
  ///
  /// To be able to directly call [Theme.of], [MediaQuery.of], etc, in the code
  /// that sets the [home] argument in the constructor, you can use a [Builder]
  /// widget to get a [BuildContext].
  ///
  /// If [home] is specified, then [routes] must not include an entry for `/`,
  /// as [home] takes its place.
  ///
  /// The [Navigator] is only built if routes are provided (either via [home],
  /// [routes], [onGenerateRoute], or [onUnknownRoute]); if they are not,
  /// [builder] must not be null.
  ///
  /// The difference between using [home] and using [builder] is that the [home]
  /// subtree is inserted into the application below a [Navigator] (and thus
  /// below an [Overlay], which [Navigator] uses). With [home], therefore,
  /// dialog boxes will work automatically, the [routes] table will be used, and
  /// APIs such as [Navigator.push] and [Navigator.pop] will work as expected.
  /// In contrast, the widget returned from [builder] is inserted _above_ the
  /// app's [Navigator] (if any).
  /// {@endtemplate}
  ///
  /// If this property is set, the [pageRouteBuilder] property must also be set
  /// so that the default route handler will know what kind of [PageRoute]s to
  /// build.
  final Widget? home;

  /// The application's top-level routing table.
  ///
  /// When a named route is pushed with [Navigator.pushNamed], the route name is
  /// looked up in this map. If the name is present, the associated
  /// [WidgetBuilder] is used to construct a [PageRoute] specified by
  /// [pageRouteBuilder] to perform an appropriate transition, including [Hero]
  /// animations, to the new route.
  ///
  /// {@template flutter.widgets.widgetsApp.routes}
  /// If the app only has one page, then you can specify it using [home] instead.
  ///
  /// If [home] is specified, then it implies an entry in this table for the
  /// [Navigator.defaultRouteName] route (`/`), and it is an error to
  /// redundantly provide such a route in the [routes] table.
  ///
  /// If a route is requested that is not specified in this table (or by
  /// [home]), then the [onGenerateRoute] callback is called to build the page
  /// instead.
  ///
  /// The [Navigator] is only built if routes are provided (either via [home],
  /// [routes], [onGenerateRoute], or [onUnknownRoute]); if they are not,
  /// [builder] must not be null.
  /// {@endtemplate}
  ///
  /// If the routes map is not empty, the [pageRouteBuilder] property must be set
  /// so that the default route handler will know what kind of [PageRoute]s to
  /// build.
  final Map<String, WidgetBuilder>? routes;

  /// {@template flutter.widgets.widgetsApp.onUnknownRoute}
  /// Called when [onGenerateRoute] fails to generate a route, except for the
  /// [initialRoute].
  ///
  /// This callback is typically used for error handling. For example, this
  /// callback might always generate a "not found" page that describes the route
  /// that wasn't found.
  ///
  /// Unknown routes can arise either from errors in the app or from external
  /// requests to push routes, such as from Android intents.
  ///
  /// The [Navigator] is only built if routes are provided (either via [home],
  /// [routes], [onGenerateRoute], or [onUnknownRoute]); if they are not,
  /// [builder] must not be null.
  /// {@endtemplate}
  final RouteFactory? onUnknownRoute;

  /// {@template flutter.widgets.widgetsApp.initialRoute}
  /// The name of the first route to show, if a [Navigator] is built.
  ///
  /// Defaults to [dart:ui.PlatformDispatcher.defaultRouteName], which may be
  /// overridden by the code that launched the application.
  ///
  /// If the route name starts with a slash, then it is treated as a "deep link",
  /// and before this route is pushed, the routes leading to this one are pushed
  /// also. For example, if the route was `/a/b/c`, then the app would start
  /// with the four routes `/`, `/a`, `/a/b`, and `/a/b/c` loaded, in that order.
  /// Even if the route was just `/a`, the app would start with `/` and `/a`
  /// loaded. You can use the [onGenerateInitialRoutes] property to override
  /// this behavior.
  ///
  /// Intermediate routes aren't required to exist. In the example above, `/a`
  /// and `/a/b` could be skipped if they have no matching route. But `/a/b/c` is
  /// required to have a route, else [initialRoute] is ignored and
  /// [Navigator.defaultRouteName] is used instead (`/`). This can happen if the
  /// app is started with an intent that specifies a non-existent route.
  ///
  /// The [Navigator] is only built if routes are provided (either via [home],
  /// [routes], [onGenerateRoute], or [onUnknownRoute]); if they are not,
  /// [initialRoute] must be null and [builder] must not be null.
  ///
  /// See also:
  ///
  ///  * [Navigator.initialRoute], which is used to implement this property.
  ///  * [Navigator.push], for pushing additional routes.
  ///  * [Navigator.pop], for removing a route from the stack.
  ///
  /// {@endtemplate}
  final String? initialRoute;

  /// {@template flutter.widgets.widgetsApp.navigatorObservers}
  /// The list of observers for the [Navigator] created for this app.
  ///
  /// This list must be replaced by a list of newly-created observers if the
  /// [navigatorKey] is changed.
  ///
  /// The [Navigator] is only built if routes are provided (either via [home],
  /// [routes], [onGenerateRoute], or [onUnknownRoute]); if they are not,
  /// [navigatorObservers] must be the empty list and [builder] must not be null.
  /// {@endtemplate}
  final List<NavigatorObserver>? navigatorObservers;

  /// {@template flutter.widgets.widgetsApp.builder}
  /// A builder for inserting widgets above the [Navigator] or - when the
  /// [WidgetsApp.router] constructor is used - above the [Router] but below the
  /// other widgets created by the [WidgetsApp] widget, or for replacing the
  /// [Navigator]/[Router] entirely.
  ///
  /// For example, from the [BuildContext] passed to this method, the
  /// [Directionality], [Localizations], [DefaultTextStyle], [MediaQuery], etc,
  /// are all available. They can also be overridden in a way that impacts all
  /// the routes in the [Navigator] or [Router].
  ///
  /// This is rarely useful, but can be used in applications that wish to
  /// override those defaults, e.g. to force the application into right-to-left
  /// mode despite being in English, or to override the [MediaQuery] metrics
  /// (e.g. to leave a gap for advertisements shown by a plugin from OEM code).
  ///
  /// For specifically overriding the [title] with a value based on the
  /// [Localizations], consider [onGenerateTitle] instead.
  ///
  /// The [builder] callback is passed two arguments, the [BuildContext] (as
  /// `context`) and a [Navigator] or [Router] widget (as `child`).
  ///
  /// If no routes are provided to the regular [WidgetsApp] constructor using
  /// [home], [routes], [onGenerateRoute], or [onUnknownRoute], the `child` will
  /// be null, and it is the responsibility of the [builder] to provide the
  /// application's routing machinery.
  ///
  /// If routes _are_ provided to the regular [WidgetsApp] constructor using one
  /// or more of those properties or if the [WidgetsApp.router] constructor is
  /// used, then `child` is not null, and the returned value should include the
  /// `child` in the widget subtree; if it does not, then the application will
  /// have no [Navigator] or [Router] and the routing related properties (i.e.
  /// [navigatorKey], [home], [routes], [onGenerateRoute], [onUnknownRoute],
  /// [initialRoute], [navigatorObservers], [routeInformationProvider],
  /// [backButtonDispatcher], [routerDelegate], and [routeInformationParser])
  /// are ignored.
  ///
  /// If [builder] is null, it is as if a builder was specified that returned
  /// the `child` directly. If it is null, routes must be provided using one of
  /// the other properties listed above.
  ///
  /// Unless a [Navigator] is provided, either implicitly from [builder] being
  /// null, or by a [builder] including its `child` argument, or by a [builder]
  /// explicitly providing a [Navigator] of its own, or by the [routerDelegate]
  /// building one, widgets and APIs such as [Hero], [Navigator.push] and
  /// [Navigator.pop], will not function.
  /// {@endtemplate}
  final TransitionBuilder? builder;

  /// {@template flutter.widgets.widgetsApp.title}
  /// A one-line description used by the device to identify the app for the user.
  ///
  /// On Android the titles appear above the task manager's app snapshots which are
  /// displayed when the user presses the "recent apps" button. On iOS this
  /// value cannot be used. `CFBundleDisplayName` from the app's `Info.plist` is
  /// referred to instead whenever present, `CFBundleName` otherwise.
  /// On the web it is used as the page title, which shows up in the browser's list of open tabs.
  ///
  /// To provide a localized title instead, use [onGenerateTitle].
  /// {@endtemplate}
  final String title;

  /// {@template flutter.widgets.widgetsApp.onGenerateTitle}
  /// If non-null this callback function is called to produce the app's
  /// title string, otherwise [title] is used.
  ///
  /// The [onGenerateTitle] `context` parameter includes the [WidgetsApp]'s
  /// [Localizations] widget so that this callback can be used to produce a
  /// localized title.
  ///
  /// This callback function must not return null.
  ///
  /// The [onGenerateTitle] callback is called each time the [WidgetsApp]
  /// rebuilds.
  /// {@endtemplate}
  final GenerateAppTitle? onGenerateTitle;

  /// The default text style for [Text] in the application.
  final TextStyle? textStyle;

  /// {@template flutter.widgets.widgetsApp.color}
  /// The primary color to use for the application in the operating system
  /// interface.
  ///
  /// For example, on Android this is the color used for the application in the
  /// application switcher.
  /// {@endtemplate}
  final Color color;

  /// {@template flutter.widgets.widgetsApp.locale}
  /// The initial locale for this app's [Localizations] widget is based
  /// on this value.
  ///
  /// If the 'locale' is null then the system's locale value is used.
  ///
  /// The value of [Localizations.locale] will equal this locale if
  /// it matches one of the [supportedLocales]. Otherwise it will be
  /// the first element of [supportedLocales].
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [localeResolutionCallback], which can override the default
  ///    [supportedLocales] matching algorithm.
  ///  * [localizationsDelegates], which collectively define all of the localized
  ///    resources used by this app.
  final Locale? locale;

  /// {@template flutter.widgets.widgetsApp.localizationsDelegates}
  /// The delegates for this app's [Localizations] widget.
  ///
  /// The delegates collectively define all of the localized resources
  /// for this application's [Localizations] widget.
  /// {@endtemplate}
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// {@template flutter.widgets.widgetsApp.localeListResolutionCallback}
  /// This callback is responsible for choosing the app's locale
  /// when the app is started, and when the user changes the
  /// device's locale.
  ///
  /// When a [localeListResolutionCallback] is provided, Flutter will first
  /// attempt to resolve the locale with the provided
  /// [localeListResolutionCallback]. If the callback or result is null, it will
  /// fallback to trying the [localeResolutionCallback]. If both
  /// [localeResolutionCallback] and [localeListResolutionCallback] are left
  /// null or fail to resolve (return null), the a basic fallback algorithm will
  /// be used.
  ///
  /// The priority of each available fallback is:
  ///
  ///  1. [localeListResolutionCallback] is attempted first.
  ///  1. [localeResolutionCallback] is attempted second.
  ///  1. Flutter's basic resolution algorithm, as described in
  ///     [supportedLocales], is attempted last.
  ///
  /// Properly localized projects should provide a more advanced algorithm than
  /// the basic method from [supportedLocales], as it does not implement a
  /// complete algorithm (such as the one defined in
  /// [Unicode TR35](https://unicode.org/reports/tr35/#LanguageMatching))
  /// and is optimized for speed at the detriment of some uncommon edge-cases.
  /// {@endtemplate}
  ///
  /// This callback considers the entire list of preferred locales.
  ///
  /// This algorithm should be able to handle a null or empty list of preferred locales,
  /// which indicates Flutter has not yet received locale information from the platform.
  ///
  /// See also:
  ///
  ///  * [MaterialApp.localeListResolutionCallback], which sets the callback of the
  ///    [WidgetsApp] it creates.
  final LocaleListResolutionCallback? localeListResolutionCallback;

  /// {@macro flutter.widgets.widgetsApp.localeListResolutionCallback}
  ///
  /// This callback considers only the default locale, which is the first locale
  /// in the preferred locales list. It is preferred to set [localeListResolutionCallback]
  /// over [localeResolutionCallback] as it provides the full preferred locales list.
  ///
  /// This algorithm should be able to handle a null locale, which indicates
  /// Flutter has not yet received locale information from the platform.
  ///
  /// See also:
  ///
  ///  * [MaterialApp.localeResolutionCallback], which sets the callback of the
  ///    [WidgetsApp] it creates.
  final LocaleResolutionCallback? localeResolutionCallback;

  /// {@template flutter.widgets.widgetsApp.supportedLocales}
  /// The list of locales that this app has been localized for.
  ///
  /// By default only the American English locale is supported. Apps should
  /// configure this list to match the locales they support.
  ///
  /// This list must not null. Its default value is just
  /// `[const Locale('en', 'US')]`.
  ///
  /// The order of the list matters. The default locale resolution algorithm,
  /// `basicLocaleListResolution`, attempts to match by the following priority:
  ///
  ///  1. [Locale.languageCode], [Locale.scriptCode], and [Locale.countryCode]
  ///  2. [Locale.languageCode] and [Locale.scriptCode] only
  ///  3. [Locale.languageCode] and [Locale.countryCode] only
  ///  4. [Locale.languageCode] only
  ///  5. [Locale.countryCode] only when all preferred locales fail to match
  ///  6. Returns the first element of [supportedLocales] as a fallback
  ///
  /// When more than one supported locale matches one of these criteria, only
  /// the first matching locale is returned.
  ///
  /// The default locale resolution algorithm can be overridden by providing a
  /// value for [localeListResolutionCallback]. The provided
  /// `basicLocaleListResolution` is optimized for speed and does not implement
  /// a full algorithm (such as the one defined in
  /// [Unicode TR35](https://unicode.org/reports/tr35/#LanguageMatching)) that
  /// takes distances between languages into account.
  ///
  /// When supporting languages with more than one script, it is recommended
  /// to specify the [Locale.scriptCode] explicitly. Locales may also be defined without
  /// [Locale.countryCode] to specify a generic fallback for a particular script.
  ///
  /// A fully supported language with multiple scripts should define a generic language-only
  /// locale (e.g. 'zh'), language+script only locales (e.g. 'zh_Hans' and 'zh_Hant'),
  /// and any language+script+country locales (e.g. 'zh_Hans_CN'). Fully defining all of
  /// these locales as supported is not strictly required but allows for proper locale resolution in
  /// the most number of cases. These locales can be specified with the [Locale.fromSubtags]
  /// constructor:
  ///
  /// ```dart
  /// // Full Chinese support for CN, TW, and HK
  /// supportedLocales: [
  ///   const Locale.fromSubtags(languageCode: 'zh'), // generic Chinese 'zh'
  ///   const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), // generic simplified Chinese 'zh_Hans'
  ///   const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), // generic traditional Chinese 'zh_Hant'
  ///   const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'), // 'zh_Hans_CN'
  ///   const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'), // 'zh_Hant_TW'
  ///   const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'), // 'zh_Hant_HK'
  /// ],
  /// ```
  ///
  /// Omitting some these fallbacks may result in improperly resolved
  /// edge-cases, for example, a simplified Chinese user in Taiwan ('zh_Hans_TW')
  /// may resolve to traditional Chinese if 'zh_Hans' and 'zh_Hans_CN' are
  /// omitted.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [MaterialApp.supportedLocales], which sets the `supportedLocales`
  ///    of the [WidgetsApp] it creates.
  ///  * [localeResolutionCallback], an app callback that resolves the app's locale
  ///    when the device's locale changes.
  ///  * [localizationsDelegates], which collectively define all of the localized
  ///    resources used by this app.
  final Iterable<Locale> supportedLocales;

  /// Turns on a performance overlay.
  ///
  /// See also:
  ///
  ///  * <https://flutter.dev/debugging/#performanceoverlay>
  final bool showPerformanceOverlay;

  /// Checkerboards raster cache images.
  ///
  /// See [PerformanceOverlay.checkerboardRasterCacheImages].
  final bool checkerboardRasterCacheImages;

  /// Checkerboards layers rendered to offscreen bitmaps.
  ///
  /// See [PerformanceOverlay.checkerboardOffscreenLayers].
  final bool checkerboardOffscreenLayers;

  /// Turns on an overlay that shows the accessibility information
  /// reported by the framework.
  final bool showSemanticsDebugger;

  /// Turns on an overlay that enables inspecting the widget tree.
  ///
  /// The inspector is only available in checked mode as it depends on
  /// [RenderObject.debugDescribeChildren] which should not be called outside of
  /// checked mode.
  final bool debugShowWidgetInspector;

  /// Builds the widget the [WidgetInspector] uses to switch between view and
  /// inspect modes.
  ///
  /// This lets [MaterialApp] to use a material button to toggle the inspector
  /// select mode without requiring [WidgetInspector] to depend on the
  /// material package.
  final InspectorSelectButtonBuilder? inspectorSelectButtonBuilder;

  /// {@template flutter.widgets.widgetsApp.debugShowCheckedModeBanner}
  /// Turns on a little "DEBUG" banner in checked mode to indicate
  /// that the app is in checked mode. This is on by default (in
  /// checked mode), to turn it off, set the constructor argument to
  /// false. In release mode this has no effect.
  ///
  /// To get this banner in your application if you're not using
  /// WidgetsApp, include a [CheckedModeBanner] widget in your app.
  ///
  /// This banner is intended to deter people from complaining that your
  /// app is slow when it's in checked mode. In checked mode, Flutter
  /// enables a large number of expensive diagnostics to aid in
  /// development, and so performance in checked mode is not
  /// representative of what will happen in release mode.
  /// {@endtemplate}
  final bool debugShowCheckedModeBanner;

  /// {@template flutter.widgets.widgetsApp.shortcuts}
  /// The default map of keyboard shortcuts to intents for the application.
  ///
  /// By default, this is set to [WidgetsApp.defaultShortcuts].
  /// {@endtemplate}
  ///
  /// {@tool snippet}
  /// This example shows how to add a single shortcut for
  /// [LogicalKeyboardKey.select] to the default shortcuts without needing to
  /// add your own [Shortcuts] widget.
  ///
  /// Alternatively, you could insert a [Shortcuts] widget with just the mapping
  /// you want to add between the [WidgetsApp] and its child and get the same
  /// effect.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   return WidgetsApp(
  ///     shortcuts: <LogicalKeySet, Intent>{
  ///       ... WidgetsApp.defaultShortcuts,
  ///       LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
  ///     },
  ///     color: const Color(0xFFFF0000),
  ///     builder: (BuildContext context, Widget child) {
  ///       return const Placeholder();
  ///     },
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@template flutter.widgets.widgetsApp.shortcuts.seeAlso}
  /// See also:
  ///
  ///  * [LogicalKeySet], a set of [LogicalKeyboardKey]s that make up the keys
  ///    for this map.
  ///  * The [Shortcuts] widget, which defines a keyboard mapping.
  ///  * The [Actions] widget, which defines the mapping from intent to action.
  ///  * The [Intent] and [Action] classes, which allow definition of new
  ///    actions.
  /// {@endtemplate}
  final Map<LogicalKeySet, Intent>? shortcuts;

  /// {@template flutter.widgets.widgetsApp.actions}
  /// The default map of intent keys to actions for the application.
  ///
  /// By default, this is the output of [WidgetsApp.defaultActions], called with
  /// [defaultTargetPlatform]. Specifying [actions] for an app overrides the
  /// default, so if you wish to modify the default [actions], you can call
  /// [WidgetsApp.defaultActions] and modify the resulting map, passing it as
  /// the [actions] for this app. You may also add to the bindings, or override
  /// specific bindings for a widget subtree, by adding your own [Actions]
  /// widget.
  /// {@endtemplate}
  ///
  /// {@tool snippet}
  /// This example shows how to add a single action handling an
  /// [ActivateAction] to the default actions without needing to
  /// add your own [Actions] widget.
  ///
  /// Alternatively, you could insert a [Actions] widget with just the mapping
  /// you want to add between the [WidgetsApp] and its child and get the same
  /// effect.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   return WidgetsApp(
  ///     actions: <Type, Action<Intent>>{
  ///       ... WidgetsApp.defaultActions,
  ///       ActivateAction: CallbackAction(
  ///         onInvoke: (Intent intent) {
  ///           // Do something here...
  ///           return null;
  ///         },
  ///       ),
  ///     },
  ///     color: const Color(0xFFFF0000),
  ///     builder: (BuildContext context, Widget child) {
  ///       return const Placeholder();
  ///     },
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@template flutter.widgets.widgetsApp.actions.seeAlso}
  /// See also:
  ///
  ///  * The [shortcuts] parameter, which defines the default set of shortcuts
  ///    for the application.
  ///  * The [Shortcuts] widget, which defines a keyboard mapping.
  ///  * The [Actions] widget, which defines the mapping from intent to action.
  ///  * The [Intent] and [Action] classes, which allow definition of new
  ///    actions.
  /// {@endtemplate}
  final Map<Type, Action<Intent>>? actions;

  /// {@template flutter.widgets.widgetsApp.restorationScopeId}
  /// The identifier to use for state restoration of this app.
  ///
  /// Providing a restoration ID inserts a [RootRestorationScope] into the
  /// widget hierarchy, which enables state restoration for descendant widgets.
  ///
  /// Providing a restoration ID also enables the [Navigator] built by the
  /// [WidgetsApp] to restore its state (i.e. to restore the history stack of
  /// active [Route]s). See the documentation on [Navigator] for more details
  /// around state restoration of [Route]s.
  ///
  /// See also:
  ///
  ///  * [RestorationManager], which explains how state restoration works in
  ///    Flutter.
  /// {@endtemplate}
  final String? restorationScopeId;

  /// If true, forces the performance overlay to be visible in all instances.
  ///
  /// Used by the `showPerformanceOverlay` observatory extension.
  static bool showPerformanceOverlayOverride = false;

  /// If true, forces the widget inspector to be visible.
  ///
  /// Used by the `debugShowWidgetInspector` debugging extension.
  ///
  /// The inspector allows you to select a location on your device or emulator
  /// and view what widgets and render objects associated with it. An outline of
  /// the selected widget and some summary information is shown on device and
  /// more detailed information is shown in the IDE or Observatory.
  static bool debugShowWidgetInspectorOverride = false;

  /// If false, prevents the debug banner from being visible.
  ///
  /// Used by the `debugAllowBanner` observatory extension.
  ///
  /// This is how `flutter run` turns off the banner when you take a screen shot
  /// with "s".
  static bool debugAllowBannerOverride = true;

  static final Map<LogicalKeySet, Intent> _defaultShortcuts = <LogicalKeySet, Intent>{
    // Activation
    LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
    LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
    LogicalKeySet(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),

    // Dismissal
    LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),

    // Keyboard traversal.
    LogicalKeySet(LogicalKeyboardKey.tab): const NextFocusIntent(),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): const PreviousFocusIntent(),
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
    LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
    LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
    LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),

    // Scrolling
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp): const ScrollIntent(direction: AxisDirection.up),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown): const ScrollIntent(direction: AxisDirection.down),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft): const ScrollIntent(direction: AxisDirection.left),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowRight): const ScrollIntent(direction: AxisDirection.right),
    LogicalKeySet(LogicalKeyboardKey.pageUp): const ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    LogicalKeySet(LogicalKeyboardKey.pageDown): const ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
  };

  // Default shortcuts for the web platform.
  static final Map<LogicalKeySet, Intent> _defaultWebShortcuts = <LogicalKeySet, Intent>{
    // Activation
    LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),

    // Dismissal
    LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),

    // Keyboard traversal.
    LogicalKeySet(LogicalKeyboardKey.tab): const NextFocusIntent(),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): const PreviousFocusIntent(),

    // Scrolling
    LogicalKeySet(LogicalKeyboardKey.arrowUp): const ScrollIntent(direction: AxisDirection.up),
    LogicalKeySet(LogicalKeyboardKey.arrowDown): const ScrollIntent(direction: AxisDirection.down),
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): const ScrollIntent(direction: AxisDirection.left),
    LogicalKeySet(LogicalKeyboardKey.arrowRight): const ScrollIntent(direction: AxisDirection.right),
    LogicalKeySet(LogicalKeyboardKey.pageUp): const ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    LogicalKeySet(LogicalKeyboardKey.pageDown): const ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
    LogicalKeySet(LogicalKeyboardKey.space): const ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
  };

  // Default shortcuts for the macOS platform.
  static final Map<LogicalKeySet, Intent> _defaultMacOsShortcuts = <LogicalKeySet, Intent>{
    // Activation
    LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
    LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),

    // Dismissal
    LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),

    // Keyboard traversal
    LogicalKeySet(LogicalKeyboardKey.tab): const NextFocusIntent(),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): const PreviousFocusIntent(),
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
    LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
    LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
    LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),

    // Scrolling
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowUp): const ScrollIntent(direction: AxisDirection.up),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowDown): const ScrollIntent(direction: AxisDirection.down),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowLeft): const ScrollIntent(direction: AxisDirection.left),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowRight): const ScrollIntent(direction: AxisDirection.right),
    LogicalKeySet(LogicalKeyboardKey.pageUp): const ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    LogicalKeySet(LogicalKeyboardKey.pageDown): const ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
  };

  /// Generates the default shortcut key bindings based on the
  /// [defaultTargetPlatform].
  ///
  /// Used by [WidgetsApp] to assign a default value to [WidgetsApp.shortcuts].
  static Map<LogicalKeySet, Intent> get defaultShortcuts {
    if (kIsWeb) {
      return _defaultWebShortcuts;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _defaultShortcuts;
      case TargetPlatform.macOS:
        return _defaultMacOsShortcuts;
      case TargetPlatform.iOS:
        // No keyboard support on iOS yet.
        break;
    }
    return <LogicalKeySet, Intent>{};
  }

  /// The default value of [WidgetsApp.actions].
  static Map<Type, Action<Intent>> defaultActions = <Type, Action<Intent>>{
    DoNothingIntent: DoNothingAction(),
    DoNothingAndStopPropagationIntent: DoNothingAction(consumesKey: false),
    RequestFocusIntent: RequestFocusAction(),
    NextFocusIntent: NextFocusAction(),
    PreviousFocusIntent: PreviousFocusAction(),
    DirectionalFocusIntent: DirectionalFocusAction(),
    ScrollIntent: ScrollAction(),
  };

  @override
  _WidgetsAppState createState() => _WidgetsAppState();
}

class _WidgetsAppState extends State<WidgetsApp> with WidgetsBindingObserver {
  // STATE LIFECYCLE

  // If window.defaultRouteName isn't '/', we should assume it was set
  // intentionally via `setInitialRoute`, and should override whatever is in
  // [widget.initialRoute].
  String get _initialRouteName => WidgetsBinding.instance!.platformDispatcher.defaultRouteName != Navigator.defaultRouteName
    ? WidgetsBinding.instance!.platformDispatcher.defaultRouteName
    : widget.initialRoute ?? WidgetsBinding.instance!.platformDispatcher.defaultRouteName;

  @override
  void initState() {
    super.initState();
    _updateRouting();
    _locale = _resolveLocales(WidgetsBinding.instance!.platformDispatcher.locales, widget.supportedLocales);
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didUpdateWidget(WidgetsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRouting(oldWidget: oldWidget);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _defaultRouteInformationProvider?.dispose();
    super.dispose();
  }

  void _updateRouting({WidgetsApp? oldWidget}) {
    if (_usesRouter) {
      assert(!_usesNavigator);
      _navigator = null;
      if (oldWidget == null || oldWidget.routeInformationProvider != widget.routeInformationProvider) {
        _defaultRouteInformationProvider?.dispose();
        _defaultRouteInformationProvider = null;
        if (widget.routeInformationProvider == null) {
          _defaultRouteInformationProvider = PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(
              location: _initialRouteName,
            ),
          );
        }
      }
    } else if (_usesNavigator) {
      assert(!_usesRouter);
      _defaultRouteInformationProvider?.dispose();
      _defaultRouteInformationProvider = null;
      if (oldWidget == null || widget.navigatorKey != oldWidget.navigatorKey) {
        _navigator = widget.navigatorKey ?? GlobalObjectKey<NavigatorState>(this);
      }
      assert(_navigator != null);
    } else {
      assert(widget.builder != null);
      assert(!_usesRouter);
      assert(!_usesNavigator);
      _navigator = null;
      _defaultRouteInformationProvider?.dispose();
      _defaultRouteInformationProvider = null;
    }
    // If we use a navigator, we have a navigator key.
    assert(_usesNavigator == (_navigator != null));
  }

  bool get _usesRouter => widget.routerDelegate != null;
  bool get _usesNavigator => widget.home != null || widget.routes?.isNotEmpty == true || widget.onGenerateRoute != null || widget.onUnknownRoute != null;

  // ROUTER

  RouteInformationProvider? get _effectiveRouteInformationProvider => widget.routeInformationProvider ?? _defaultRouteInformationProvider;
  PlatformRouteInformationProvider? _defaultRouteInformationProvider;

  // NAVIGATOR

  GlobalKey<NavigatorState>? _navigator;

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final WidgetBuilder? pageContentBuilder = name == Navigator.defaultRouteName && widget.home != null
        ? (BuildContext context) => widget.home!
        : widget.routes![name];

    if (pageContentBuilder != null) {
      assert(widget.pageRouteBuilder != null,
        'The default onGenerateRoute handler for WidgetsApp must have a '
        'pageRouteBuilder set if the home or routes properties are set.');
      final Route<dynamic> route = widget.pageRouteBuilder!<dynamic>(
        settings,
        pageContentBuilder,
      );
      assert(route != null,
        'The pageRouteBuilder for WidgetsApp must return a valid non-null Route.');
      return route;
    }
    if (widget.onGenerateRoute != null)
      return widget.onGenerateRoute!(settings);
    return null;
  }

  Route<dynamic> _onUnknownRoute(RouteSettings settings) {
    assert(() {
      if (widget.onUnknownRoute == null) {
        throw FlutterError(
          'Could not find a generator for route $settings in the $runtimeType.\n'
          'Make sure your root app widget has provided a way to generate \n'
          'this route.\n'
          'Generators for routes are searched for in the following order:\n'
          ' 1. For the "/" route, the "home" property, if non-null, is used.\n'
          ' 2. Otherwise, the "routes" table is used, if it has an entry for '
          'the route.\n'
          ' 3. Otherwise, onGenerateRoute is called. It should return a '
          'non-null value for any valid route not handled by "home" and "routes".\n'
          ' 4. Finally if all else fails onUnknownRoute is called.\n'
          'Unfortunately, onUnknownRoute was not set.'
        );
      }
      return true;
    }());
    final Route<dynamic>? result = widget.onUnknownRoute!(settings);
    assert(() {
      if (result == null) {
        throw FlutterError(
          'The onUnknownRoute callback returned null.\n'
          'When the $runtimeType requested the route $settings from its '
          'onUnknownRoute callback, the callback returned null. Such callbacks '
          'must never return null.'
        );
      }
      return true;
    }());
    return result!;
  }

  // On Android: the user has pressed the back button.
  @override
  Future<bool> didPopRoute() async {
    assert(mounted);
    // The back button dispatcher should handle the pop route if we use a
    // router.
    if (_usesRouter)
      return false;

    final NavigatorState? navigator = _navigator?.currentState;
    if (navigator == null)
      return false;
    return await navigator.maybePop();
  }

  @override
  Future<bool> didPushRoute(String route) async {
    assert(mounted);
    // The route name provider should handle the push route if we uses a
    // router.
    if (_usesRouter)
      return false;

    final NavigatorState? navigator = _navigator?.currentState;
    if (navigator == null)
      return false;
    navigator.pushNamed(route);
    return true;
  }

  // LOCALIZATION

  /// This is the resolved locale, and is one of the supportedLocales.
  Locale? _locale;

  Locale _resolveLocales(List<Locale>? preferredLocales, Iterable<Locale> supportedLocales) {
    // Attempt to use localeListResolutionCallback.
    if (widget.localeListResolutionCallback != null) {
      final Locale? locale = widget.localeListResolutionCallback!(preferredLocales, widget.supportedLocales);
      if (locale != null)
        return locale;
    }
    // localeListResolutionCallback failed, falling back to localeResolutionCallback.
    if (widget.localeResolutionCallback != null) {
      final Locale? locale = widget.localeResolutionCallback!(
        preferredLocales != null && preferredLocales.isNotEmpty ? preferredLocales.first : null,
        widget.supportedLocales,
      );
      if (locale != null)
        return locale;
    }
    // Both callbacks failed, falling back to default algorithm.
    return basicLocaleListResolution(preferredLocales, supportedLocales);
  }

  /// The default locale resolution algorithm.
  ///
  /// Custom resolution algorithms can be provided through
  /// [WidgetsApp.localeListResolutionCallback] or
  /// [WidgetsApp.localeResolutionCallback].
  ///
  /// When no custom locale resolution algorithms are provided or if both fail
  /// to resolve, Flutter will default to calling this algorithm.
  ///
  /// This algorithm prioritizes speed at the cost of slightly less appropriate
  /// resolutions for edge cases.
  ///
  /// This algorithm will resolve to the earliest preferred locale that
  /// matches the most fields, prioritizing in the order of perfect match,
  /// languageCode+countryCode, languageCode+scriptCode, languageCode-only.
  ///
  /// In the case where a locale is matched by languageCode-only and is not the
  /// default (first) locale, the next preferred locale with a
  /// perfect match can supersede the languageCode-only match if it exists.
  ///
  /// When a preferredLocale matches more than one supported locale, it will
  /// resolve to the first matching locale listed in the supportedLocales.
  ///
  /// When all preferred locales have been exhausted without a match, the first
  /// countryCode only match will be returned.
  ///
  /// When no match at all is found, the first (default) locale in
  /// [supportedLocales] will be returned.
  ///
  /// To summarize, the main matching priority is:
  ///
  ///  1. [Locale.languageCode], [Locale.scriptCode], and [Locale.countryCode]
  ///  1. [Locale.languageCode] and [Locale.scriptCode] only
  ///  1. [Locale.languageCode] and [Locale.countryCode] only
  ///  1. [Locale.languageCode] only (with caveats, see above)
  ///  1. [Locale.countryCode] only when all [preferredLocales] fail to match
  ///  1. Returns the first element of [supportedLocales] as a fallback
  ///
  /// This algorithm does not take language distance (how similar languages are to each other)
  /// into account, and will not handle edge cases such as resolving `de` to `fr` rather than `zh`
  /// when `de` is not supported and `zh` is listed before `fr` (German is closer to French
  /// than Chinese).
  static Locale basicLocaleListResolution(List<Locale>? preferredLocales, Iterable<Locale> supportedLocales) {
    // preferredLocales can be null when called before the platform has had a chance to
    // initialize the locales. Platforms without locale passing support will provide an empty list.
    // We default to the first supported locale in these cases.
    if (preferredLocales == null || preferredLocales.isEmpty) {
      return supportedLocales.first;
    }
    // Hash the supported locales because apps can support many locales and would
    // be expensive to search through them many times.
    final Map<String, Locale> allSupportedLocales = HashMap<String, Locale>();
    final Map<String, Locale> languageAndCountryLocales = HashMap<String, Locale>();
    final Map<String, Locale> languageAndScriptLocales = HashMap<String, Locale>();
    final Map<String, Locale> languageLocales = HashMap<String, Locale>();
    final Map<String?, Locale> countryLocales = HashMap<String?, Locale>();
    for (final Locale locale in supportedLocales) {
      allSupportedLocales['${locale.languageCode}_${locale.scriptCode}_${locale.countryCode}'] ??= locale;
      languageAndScriptLocales['${locale.languageCode}_${locale.scriptCode}'] ??= locale;
      languageAndCountryLocales['${locale.languageCode}_${locale.countryCode}'] ??= locale;
      languageLocales[locale.languageCode] ??= locale;
      countryLocales[locale.countryCode] ??= locale;
    }

    // Since languageCode-only matches are possibly low quality, we don't return
    // it instantly when we find such a match. We check to see if the next
    // preferred locale in the list has a high accuracy match, and only return
    // the languageCode-only match when a higher accuracy match in the next
    // preferred locale cannot be found.
    Locale? matchesLanguageCode;
    Locale? matchesCountryCode;
    // Loop over user's preferred locales
    for (int localeIndex = 0; localeIndex < preferredLocales.length; localeIndex += 1) {
      final Locale userLocale = preferredLocales[localeIndex];
      // Look for perfect match.
      if (allSupportedLocales.containsKey('${userLocale.languageCode}_${userLocale.scriptCode}_${userLocale.countryCode}')) {
        return userLocale;
      }
      // Look for language+script match.
      if (userLocale.scriptCode != null) {
        final Locale? match = languageAndScriptLocales['${userLocale.languageCode}_${userLocale.scriptCode}'];
        if (match != null) {
          return match;
        }
      }
      // Look for language+country match.
      if (userLocale.countryCode != null) {
        final Locale? match = languageAndCountryLocales['${userLocale.languageCode}_${userLocale.countryCode}'];
        if (match != null) {
          return match;
        }
      }
      // If there was a languageCode-only match in the previous iteration's higher
      // ranked preferred locale, we return it if the current userLocale does not
      // have a better match.
      if (matchesLanguageCode != null) {
        return matchesLanguageCode;
      }
      // Look and store language-only match.
      Locale? match = languageLocales[userLocale.languageCode];
      if (match != null) {
        matchesLanguageCode = match;
        // Since first (default) locale is usually highly preferred, we will allow
        // a languageCode-only match to be instantly matched. If the next preferred
        // languageCode is the same, we defer hastily returning until the next iteration
        // since at worst it is the same and at best an improved match.
        if (localeIndex == 0 &&
            !(localeIndex + 1 < preferredLocales.length && preferredLocales[localeIndex + 1].languageCode == userLocale.languageCode)) {
          return matchesLanguageCode;
        }
      }
      // countryCode-only match. When all else except default supported locale fails,
      // attempt to match by country only, as a user is likely to be familiar with a
      // language from their listed country.
      if (matchesCountryCode == null && userLocale.countryCode != null) {
        match = countryLocales[userLocale.countryCode];
        if (match != null) {
          matchesCountryCode = match;
        }
      }
    }
    // When there is no languageCode-only match. Fallback to matching countryCode only. Country
    // fallback only applies on iOS. When there is no countryCode-only match, we return first
    // supported locale.
    final Locale resolvedLocale = matchesLanguageCode ?? matchesCountryCode ?? supportedLocales.first;
    return resolvedLocale;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final Locale newLocale = _resolveLocales(locales, widget.supportedLocales);
    if (newLocale != _locale) {
      setState(() {
        _locale = newLocale;
      });
    }
  }

  // Combine the Localizations for Widgets with the ones contributed
  // by the localizationsDelegates parameter, if any. Only the first delegate
  // of a particular LocalizationsDelegate.type is loaded so the
  // localizationsDelegate parameter can be used to override
  // WidgetsLocalizations.delegate.
  Iterable<LocalizationsDelegate<dynamic>> get _localizationsDelegates sync* {
    if (widget.localizationsDelegates != null)
      yield* widget.localizationsDelegates!;
    yield DefaultWidgetsLocalizations.delegate;
  }

  // BUILDER

  bool _debugCheckLocalizations(Locale appLocale) {
    assert(() {
      final Set<Type> unsupportedTypes =
        _localizationsDelegates.map<Type>((LocalizationsDelegate<dynamic> delegate) => delegate.type).toSet();
      for (final LocalizationsDelegate<dynamic> delegate in _localizationsDelegates) {
        if (!unsupportedTypes.contains(delegate.type))
          continue;
        if (delegate.isSupported(appLocale))
          unsupportedTypes.remove(delegate.type);
      }
      if (unsupportedTypes.isEmpty)
        return true;

      // Currently the Cupertino library only provides english localizations.
      // Remove this when https://github.com/flutter/flutter/issues/23847
      // is fixed.
      if (listEquals(unsupportedTypes.map((Type type) => type.toString()).toList(), <String>['CupertinoLocalizations']))
        return true;

      final StringBuffer message = StringBuffer();
      message.writeln('\u2550' * 8);
      message.writeln(
        "Warning: This application's locale, $appLocale, is not supported by all of its\n"
        'localization delegates.'
      );
      for (final Type unsupportedType in unsupportedTypes) {
        // Currently the Cupertino library only provides english localizations.
        // Remove this when https://github.com/flutter/flutter/issues/23847
        // is fixed.
        if (unsupportedType.toString() == 'CupertinoLocalizations')
          continue;
        message.writeln(
          '> A $unsupportedType delegate that supports the $appLocale locale was not found.'
        );
      }
      message.writeln(
        'See https://flutter.dev/tutorials/internationalization/ for more\n'
        "information about configuring an app's locale, supportedLocales,\n"
        'and localizationsDelegates parameters.'
      );
      message.writeln('\u2550' * 8);
      debugPrint(message.toString());
      return true;
    }());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Widget? routing;
    if (_usesRouter) {
      assert(_effectiveRouteInformationProvider != null);
      routing = Router<Object>(
        routeInformationProvider: _effectiveRouteInformationProvider,
        routeInformationParser: widget.routeInformationParser,
        routerDelegate: widget.routerDelegate!,
        backButtonDispatcher: widget.backButtonDispatcher,
      );
    } else if (_usesNavigator) {
      assert(_navigator != null);
      routing = Navigator(
        restorationScopeId: 'nav',
        key: _navigator,
        initialRoute: _initialRouteName,
        onGenerateRoute: _onGenerateRoute,
        onGenerateInitialRoutes: widget.onGenerateInitialRoutes == null
          ? Navigator.defaultGenerateInitialRoutes
          : (NavigatorState navigator, String initialRouteName) {
            return widget.onGenerateInitialRoutes!(initialRouteName);
          },
        onUnknownRoute: _onUnknownRoute,
        observers: widget.navigatorObservers!,
        reportsRouteUpdateToEngine: true,
      );
    }

    Widget result;
    if (widget.builder != null) {
      result = Builder(
        builder: (BuildContext context) {
          return widget.builder!(context, routing);
        },
      );
    } else {
      assert(routing != null);
      result = routing!;
    }

    if (widget.textStyle != null) {
      result = DefaultTextStyle(
        style: widget.textStyle!,
        child: result,
      );
    }

    PerformanceOverlay? performanceOverlay;
    // We need to push a performance overlay if any of the display or checkerboarding
    // options are set.
    if (widget.showPerformanceOverlay || WidgetsApp.showPerformanceOverlayOverride) {
      performanceOverlay = PerformanceOverlay.allEnabled(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    } else if (widget.checkerboardRasterCacheImages || widget.checkerboardOffscreenLayers) {
      performanceOverlay = PerformanceOverlay(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    }
    if (performanceOverlay != null) {
      result = Stack(
        children: <Widget>[
          result,
          Positioned(top: 0.0, left: 0.0, right: 0.0, child: performanceOverlay),
        ],
      );
    }

    if (widget.showSemanticsDebugger) {
      result = SemanticsDebugger(
        child: result,
      );
    }

    assert(() {
      if (widget.debugShowWidgetInspector || WidgetsApp.debugShowWidgetInspectorOverride) {
        result = WidgetInspector(
          child: result,
          selectButtonBuilder: widget.inspectorSelectButtonBuilder,
        );
      }
      if (widget.debugShowCheckedModeBanner && WidgetsApp.debugAllowBannerOverride) {
        result = CheckedModeBanner(
          child: result,
        );
      }
      return true;
    }());

    final Widget title;
    if (widget.onGenerateTitle != null) {
      title = Builder(
        // This Builder exists to provide a context below the Localizations widget.
        // The onGenerateTitle callback can refer to Localizations via its context
        // parameter.
        builder: (BuildContext context) {
          final String title = widget.onGenerateTitle!(context);
          assert(title != null, 'onGenerateTitle must return a non-null String');
          return Title(
            title: title,
            color: widget.color,
            child: result,
          );
        },
      );
    } else {
      title = Title(
        title: widget.title,
        color: widget.color,
        child: result,
      );
    }

    final Locale appLocale = widget.locale != null
      ? _resolveLocales(<Locale>[widget.locale!], widget.supportedLocales)
      : _locale!;

    assert(_debugCheckLocalizations(appLocale));
    return RootRestorationScope(
      restorationId: widget.restorationScopeId,
      child: Shortcuts(
        shortcuts: widget.shortcuts ?? WidgetsApp.defaultShortcuts,
        debugLabel: '<Default WidgetsApp Shortcuts>',
        child: Actions(
          actions: widget.actions ?? WidgetsApp.defaultActions,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: _MediaQueryFromWindow(
              child: Localizations(
                locale: appLocale,
                delegates: _localizationsDelegates.toList(),
                child: title,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds [MediaQuery] from `window` by listening to [WidgetsBinding].
///
/// It is performed in a standalone widget to rebuild **only** [MediaQuery] and
/// its dependents when `window` changes, instead of rebuilding the entire widget tree.
class _MediaQueryFromWindow extends StatefulWidget {
  const _MediaQueryFromWindow({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  _MediaQueryFromWindowsState createState() => _MediaQueryFromWindowsState();
}

class _MediaQueryFromWindowsState extends State<_MediaQueryFromWindow> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  // ACCESSIBILITY

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {
      // The properties of window have changed. We use them in our build
      // function, so we need setState(), but we don't cache anything locally.
    });
  }

  // METRICS

  @override
  void didChangeMetrics() {
    setState(() {
      // The properties of window have changed. We use them in our build
      // function, so we need setState(), but we don't cache anything locally.
    });
  }

  @override
  void didChangeTextScaleFactor() {
    setState(() {
      // The textScaleFactor property of window has changed. We reference
      // window in our build function, so we need to call setState(), but
      // we don't need to cache anything locally.
    });
  }

  // RENDERING
  @override
  void didChangePlatformBrightness() {
    setState(() {
      // The platformBrightness property of window has changed. We reference
      // window in our build function, so we need to call setState(), but
      // we don't need to cache anything locally.
    });
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData data = MediaQueryData.fromWindow(WidgetsBinding.instance!.window);
    if (!kReleaseMode) {
      data = data.copyWith(platformBrightness: debugBrightnessOverride);
    }
    return MediaQuery(
      data: data,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }
}
