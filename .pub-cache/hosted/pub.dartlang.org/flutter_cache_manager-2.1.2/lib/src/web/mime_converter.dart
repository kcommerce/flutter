import 'dart:io';

///Converts the most common MIME types to the most expected file extension.
extension ContentTypeConverter on ContentType {
  String get fileExtension {
    if (this == null) return null;
    if (mimeTypes.containsKey(mimeType)) return mimeTypes[mimeType];
    return '.$subType';
  }
}

/// Source of MIME Types:
/// https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
/// Updated on 20th of March in 2020 while being quarantined
const mimeTypes = {
  'application/vnd.android.package-archive': '.apk',
  'application/epub+zip': '.epub',
  'application/gzip': '.gz',
  'application/java-archive': '.jar',
  'application/json': '.json',
  'application/ld+json': '.jsonld',
  'application/msword': '.doc',
  'application/octet-stream': '.bin',
  'application/ogg': '.ogx',
  'application/pdf': '.pdf',
  'application/php': '.php',
  'application/rtf': '.rtf',
  'application/vnd.amazon.ebook': '.azw',
  'application/vnd.apple.installer+xml': '.mpkg',
  'application/vnd.mozilla.xul+xml': '.xul',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.ms-fontobject': '.eot',
  'application/vnd.ms-powerpoint': '.ppt',
  'application/vnd.oasis.opendocument.presentation': '.odp',
  'application/vnd.oasis.opendocument.spreadsheet': '.ods',
  'application/vnd.oasis.opendocument.text': '.odt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      '.pptx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      '.docx',
  'application/vnd.rar': '.rar',
  'application/vnd.visio': '.vsd',
  'application/x-7z-compressed': '.7z',
  'application/x-abiword': '.abw',
  'application/x-bzip': '.bz',
  'application/x-bzip2': '.bz2',
  'application/x-csh': '.csh',
  'application/x-freearc': '.arc',
  'application/x-sh': '.sh',
  'application/x-shockwave-flash': '.swf',
  'application/x-tar': '.tar',
  'application/xhtml+xml': '.xhtml',
  'application/xml': '.xml',
  'application/zip': '.zip',
  'audio/3gpp': '.3gp',
  'audio/3gpp2': '.3g2',
  'audio/aac': '.aac',
  'audio/x-aac': '.aac',
  'audio/midi audio/x-midi': '.midi',
  'audio/mpeg': '.mp3',
  'audio/ogg': '.oga',
  'audio/opus': '.opus',
  'audio/wav': '.wav',
  'audio/webm': '.weba',
  'font/otf': '.otf',
  'font/ttf': '.ttf',
  'font/woff': '.woff',
  'font/woff2': '.woff2',
  'image/bmp': '.bmp',
  'image/gif': '.gif',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/svg+xml': '.svg',
  'image/tiff': '.tiff',
  'image/vnd.microsoft.icon': '.ico',
  'image/webp': '.webp',
  'text/calendar': '.ics',
  'text/css': '.css',
  'text/csv': '.csv',
  'text/html': '.html',
  'text/javascript': '.js',
  'text/plain': '.txt',
  'text/xml': '.xml',
  'video/3gpp': '.3gp',
  'video/3gpp2': '.3g2',
  'video/mp2t': '.ts',
  'video/mpeg': '.mpeg',
  'video/ogg': '.ogv',
  'video/webm': '.webm',
  'video/x-msvideo': '.avi',
  'video/quicktime': '.mov'
};
