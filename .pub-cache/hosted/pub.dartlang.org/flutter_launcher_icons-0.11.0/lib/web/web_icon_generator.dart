import 'dart:convert';

import 'package:image/image.dart';
import 'package:path/path.dart' as path;

import '../abs/icon_generator.dart';
import '../constants.dart' as constants;
import '../custom_exceptions.dart';
import '../utils.dart' as utils;
import 'web_template.dart';

// This is not yet implemented
// ignore: public_member_api_docs
final metaTagsTemplate = (
  String appleMobileWebAppTitle,
  String appleMobileWebAppStatusBarStyle, {
  bool shouldInsertFLIString = false,
}) =>
    '''
  <!--Generated by Flutter Launcher Icons-->
  <!--FLI-->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="$appleMobileWebAppStatusBarStyle">
  <meta name="apple-mobile-web-app-title" content="$appleMobileWebAppTitle">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <link rel="manifest" href="manifest.json">
  <!--FLIEND-->
  <!--Generated by Flutter Launcher Icons--END-->
''';

/// Generates Web icons for flutter
class WebIconGenerator extends IconGenerator {
  static const _webIconSizeTemplates = <WebIconTemplate>[
    WebIconTemplate(size: 192),
    WebIconTemplate(size: 512),
    WebIconTemplate(size: 192, maskable: true),
    WebIconTemplate(size: 512, maskable: true),
  ];

  /// Creates an instance of [WebIconGenerator].
  ///
  ///
  WebIconGenerator(IconGeneratorContext context) : super(context, 'Web');

  @override
  void createIcons() {
    final imgFilePath = path.join(
      context.prefixPath,
      context.webConfig!.imagePath ?? context.config.imagePath!,
    );

    context.logger
        .verbose('Decoding and loading image file at $imgFilePath...');
    final imgFile = utils.decodeImageFile(imgFilePath);
    if (imgFile == null) {
      context.logger.error('Image File not found at give path $imgFilePath...');
      throw FileNotFoundException(imgFilePath);
    }

    // generate favicon in web/favicon.png
    context.logger.verbose('Generating favicon from $imgFilePath...');
    _generateFavicon(imgFile);

    // generate icons in web/icons/
    context.logger.verbose('Generating icons from $imgFilePath...');
    _generateIcons(imgFile);

    // update manifest.json in web/mainfest.json
    context.logger.verbose(
      'Updating ${path.join(context.prefixPath, constants.webManifestFilePath)}...',
    );
    _updateManifestFile();

    // todo: update index.html in web/index.html
    // as we are using flutter default config we no need
    // to update index.html for now
    // _updateIndexFile();
  }

  @override
  bool validateRequirements() {
    // check if web config exists
    context.logger.verbose('Checking webconfig...');
    final webConfig = context.webConfig;
    if (webConfig == null || !webConfig.generate) {
      context.logger.verbose(
        'Web config is not provided or generate is false. Skipped...',
      );
      return false;
    }
    if (webConfig.imagePath == null && context.config.imagePath == null) {
      context.logger
          .verbose('Invalid config. Either provide web.imagePath or imagePath');
      return false;
    }

    // verify web platform related files and directories exists
    final entitesToCheck = [
      path.join(context.prefixPath, constants.webDirPath),
      path.join(context.prefixPath, constants.webManifestFilePath),
      path.join(context.prefixPath, constants.webIndexFilePath),
    ];

    // web platform related files must exist to continue
    final failedEntityPath = utils.areFSEntiesExist(entitesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate web icons',
      );
    }

    return true;
  }

  void _generateFavicon(Image image) {
    final favIcon = utils.createResizedImage(constants.kFaviconSize, image);
    final favIconFile = utils.createFileIfNotExist(
      path.join(context.prefixPath, constants.webFaviconFilePath),
    );
    favIconFile.writeAsBytesSync(encodePng(favIcon));
  }

  void _generateIcons(Image image) {
    final iconsDir = utils.createDirIfNotExist(
      path.join(context.prefixPath, constants.webIconsDirPath),
    );
    // generate icons
    for (final template in _webIconSizeTemplates) {
      final resizedImg = utils.createResizedImage(template.size, image);
      final iconFile = utils.createFileIfNotExist(
        path.join(context.prefixPath, iconsDir.path, template.iconFile),
      );
      iconFile.writeAsBytesSync(encodePng(resizedImg));
    }
  }

  // void _updateIndexFile() {
  // todo
  // final indexFile = File(constants.webIndexFilePath);
  // if (!indexFile.existsSync()) {
  //   throw FileNotFoundException(constants.webFaviconFilePath);
  // }
  // }

  void _updateManifestFile() {
    final manifestFile = utils.createFileIfNotExist(
      path.join(context.prefixPath, constants.webManifestFilePath),
    );
    final manifestConfig =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

    // update background_color
    if (context.webConfig?.backgroundColor != null) {
      manifestConfig['background_color'] = context.webConfig?.backgroundColor;
    }

    // update theme_color
    if (context.webConfig?.themeColor != null) {
      manifestConfig['theme_color'] = context.webConfig?.themeColor;
    }

    // replace existing icons to eliminate conflicts
    manifestConfig
      ..remove('icons')
      ..['icons'] = _webIconSizeTemplates
          .map<Map<String, dynamic>>((e) => e.iconManifest)
          .toList();

    manifestFile.writeAsStringSync(utils.prettifyJsonEncode(manifestConfig));
  }
}
