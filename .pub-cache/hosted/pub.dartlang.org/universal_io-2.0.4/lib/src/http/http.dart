// ------------------------------------------------------------------
// THIS FILE WAS DERIVED FROM SOURCE CODE UNDER THE FOLLOWING LICENSE
// ------------------------------------------------------------------
//
// Copyright 2012, the Dart project authors. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
//     * Neither the name of Google Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ---------------------------------------------------------
// THIS, DERIVED FILE IS LICENSE UNDER THE FOLLOWING LICENSE
// ---------------------------------------------------------
// Copyright 2020 terrier989@gmail.com.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library universal_io.http;

import 'dart:async';
import 'dart:collection' show HashMap, UnmodifiableMapView;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../annotations.dart';
import '../internals_for_browser_or_node.dart' as choose;
import '../io_impl_js.dart';
import 'http_status_codes.dart';

export 'http_status_codes.dart';

part 'crypto.dart';
part 'http_date.dart';
part 'http_headers.dart';
part 'http_session.dart';
part 'overrides.dart';
part 'websocket.dart';

/// A MIME/IANA media type used as the value of the
/// [HttpHeaders.contentTypeHeader] header.
///
/// A [ContentType] is immutable.
abstract class ContentType implements HeaderValue {
  /// Content type for plain text using UTF-8 encoding.
  ///
  ///     text/plain; charset=utf-8
  static final text = ContentType('text', 'plain', charset: 'utf-8');
  @Deprecated('Use text instead')
  static final TEXT = text;

  ///  Content type for HTML using UTF-8 encoding.
  ///
  ///     text/html; charset=utf-8
  static final html = ContentType('text', 'html', charset: 'utf-8');
  @Deprecated('Use html instead')
  static final HTML = html;

  ///  Content type for JSON using UTF-8 encoding.
  ///
  ///     application/json; charset=utf-8
  static final json = ContentType('application', 'json', charset: 'utf-8');
  @Deprecated('Use json instead')
  static final JSON = json;

  ///  Content type for binary data.
  ///
  ///     application/octet-stream
  static final binary = ContentType('application', 'octet-stream');
  @Deprecated('Use binary instead')
  static final BINARY = binary;

  /// Creates a new content type object setting the primary type and
  /// sub type. The charset and additional parameters can also be set
  /// using [charset] and [parameters]. If charset is passed and
  /// [parameters] contains charset as well the passed [charset] will
  /// override the value in parameters. Keys passed in parameters will be
  /// converted to lower case. The `charset` entry, whether passed as `charset`
  /// or in `parameters`, will have its value converted to lower-case.
  factory ContentType(String primaryType, String subType,
      {String? charset, Map<String, String?> parameters = const {}}) {
    return _ContentType(primaryType, subType, charset, parameters);
  }

  /// Gets the character set, if any.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [charset] value is the string `utf-8`.
  String? get charset;

  /// Gets the MIME type and subtype, without any parameters.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [mimeType] value is the string `text/html`.
  String get mimeType;

  /// Gets the primary type.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [primaryType] value is the string `text`.
  String get primaryType;

  /// Gets the subtype.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [subType] value is the string `html`.
  /// May be the empty string.
  String get subType;

  /// Creates a new content type object from parsing a Content-Type
  /// header value. As primary type, sub type and parameter names and
  /// values are not case sensitive all these values will be converted
  /// to lower case. Parsing this string
  ///
  ///     text/html; charset=utf-8
  ///
  /// will create a content type object with primary type "text",
  /// subtype "html" and parameter "charset" with value "utf-8".
  /// There may be more parameters supplied, but they are not recognized
  /// by this class.
  static ContentType parse(String value) {
    return _ContentType.parse(value);
  }
}

/// Representation of a cookie. For cookies received by the server as Cookie
/// header values only [name] and [value] properties will be set. When building a
/// cookie for the 'set-cookie' header in the server and when receiving cookies
/// in the client as 'set-cookie' headers all fields can be used.
abstract class Cookie {
  /// The name of the cookie.
  ///
  /// Must be a `token` as specified in RFC 6265.
  ///
  /// The allowed characters in a `token` are the visible ASCII characters,
  /// U+0021 (`!`) through U+007E (`~`), except the separator characters:
  /// `(`, `)`, `<`, `>`, `@`, `,`, `;`, `:`, `\`, `"`, `/`, `[`, `]`, `?`, `=`,
  /// `{`, and `}`.
  late String name;

  /// The value of the cookie.
  ///
  /// Must be a `cookie-value` as specified in RFC 6265.
  ///
  /// The allowed characters in a cookie value are the visible ASCII characters,
  /// U+0021 (`!`) through U+007E (`~`) except the characters:
  /// `"`, `,`, `;` and `\`.
  /// Cookie values may be wrapped in a single pair of double quotes
  /// (U+0022, `"`).
  late String value;

  /// The time at which the cookie expires.
  DateTime? expires;

  /// The number of seconds until the cookie expires. A zero or negative value
  /// means the cookie has expired.
  int? maxAge;

  /// The domain that the cookie applies to.
  String? domain;

  /// The path within the [domain] that the cookie applies to.
  String? path;

  /// Whether to only send this cookie on secure connections.
  bool secure = false;

  /// Whether the cookie is only sent in the HTTP request and is not made
  /// available to client side scripts.
  bool httpOnly = false;

  /// Creates a new cookie setting the name and value.
  ///
  /// [name] and [value] must be composed of valid characters according to RFC
  /// 6265.
  ///
  /// By default the value of `httpOnly` will be set to `true`.
  factory Cookie(String name, String value) => _Cookie(name, value);

  /// Creates a new cookie by parsing a header value from a 'set-cookie'
  /// header.
  factory Cookie.fromSetCookieValue(String value) {
    return _Cookie.fromSetCookieValue(value);
  }

  /// Returns the formatted string representation of the cookie. The
  /// string representation can be used for for setting the Cookie or
  /// 'set-cookie' headers
  @override
  String toString();
}

/// When detaching a socket from either the [:HttpServer:] or the
/// [:HttpClient:] due to a HTTP connection upgrade there might be
/// unparsed data already read from the socket. This unparsed data
/// together with the detached socket is returned in an instance of
/// this class.
abstract class DetachedSocket {
  Socket get socket;

  List<int> get unparsedData;
}

/// Representation of a header value in the form:
/// ```dart
/// value; parameter1=value1; parameter2=value2
/// ```
///
/// [HeaderValue] can be used to conveniently build and parse header
/// values on this form.
///
/// Parameter values can be omitted, in which case the value is parsed as `null`.
/// Values can be doubled quoted to allow characters outside of the RFC 7230
/// token characters and backslash sequences can be used to represent the double
/// quote and backslash characters themselves.
///
/// To build an "accepts" header with the value
///
///     text/plain; q=0.3, text/html
///
/// use code like this:
///
///     HttpClientRequest request = ...;
///     var v = HeaderValue("text/plain", {"q": "0.3"});
///     request.headers.add(HttpHeaders.acceptHeader, v);
///     request.headers.add(HttpHeaders.acceptHeader, "text/html");
///
/// To parse the header values use the [parse] static method.
///
///     HttpRequest request = ...;
///     List<String> values = request.headers[HttpHeaders.acceptHeader];
///     values.forEach((value) {
///       HeaderValue v = HeaderValue.parse(value);
///       // Use v.value and v.parameters
///     });
///
/// An instance of [HeaderValue] is immutable.
abstract class HeaderValue {
  /// Creates a new header value object setting the value and parameters.
  factory HeaderValue(
      [String value = '', Map<String, String?> parameters = const {}]) {
    return _HeaderValue(value, parameters);
  }

  /// A map of parameters.
  ///
  /// This map cannot be modified.
  Map<String, String?> get parameters;

  /// The value of the header.
  String get value;

  /// Returns the formatted string representation in the form:
  /// ```
  /// value; parameter1=value1; parameter2=value2
  /// ```
  @override
  String toString();

  /// Creates a new header value object from parsing a header value
  /// string with both value and optional parameters.
  static HeaderValue parse(String value,
      {String parameterSeparator = ';',
      String? valueSeparator,
      bool preserveBackslash = false}) {
    return _HeaderValue.parse(value,
        parameterSeparator: parameterSeparator,
        valueSeparator: valueSeparator,
        preserveBackslash: preserveBackslash);
  }
}

/// A client that receives content, such as web pages, from
/// a server using the HTTP protocol.
///
/// HttpClient contains a number of methods to send an [HttpClientRequest]
/// to an Http server and receive an [HttpClientResponse] back.
/// For example, you can use the [get], [getUrl], [post], and [postUrl] methods
/// for GET and POST requests, respectively.
///
/// ## Making a simple GET request: an example
///
/// A `getUrl` request is a two-step process, triggered by two [Future]s.
/// When the first future completes with a [HttpClientRequest], the underlying
/// network connection has been established, but no data has been sent.
/// In the callback function for the first future, the HTTP headers and body
/// can be set on the request. Either the first write to the request object
/// or a call to [close] sends the request to the server.
///
/// When the HTTP response is received from the server,
/// the second future, which is returned by close,
/// completes with an [HttpClientResponse] object.
/// This object provides access to the headers and body of the response.
/// The body is available as a stream implemented by HttpClientResponse.
/// If a body is present, it must be read. Otherwise, it leads to resource
/// leaks. Consider using [HttpClientResponse.drain] if the body is unused.
///
///     HttpClient client = HttpClient();
///     client.getUrl(Uri.parse("http://www.example.com/"))
///         .then((HttpClientRequest request) {
///           // Optionally set up headers...
///           // Optionally write to the request object...
///           // Then call close.
///           ...
///           return request.close();
///         })
///         .then((HttpClientResponse response) {
///           // Process the response.
///           ...
///         });
///
/// The future for [HttpClientRequest] is created by methods such as
/// [getUrl] and [open].
///
/// ## HTTPS connections
///
/// An HttpClient can make HTTPS requests, connecting to a server using
/// the TLS (SSL) secure networking protocol. Calling [getUrl] with an
/// https: scheme will work automatically, if the server's certificate is
/// signed by a root CA (certificate authority) on the default list of
/// well-known trusted CAs, compiled by Mozilla.
///
/// To add a custom trusted certificate authority, or to send a client
/// certificate to servers that request one, pass a [SecurityContext] object
/// as the optional `context` argument to the `HttpClient` constructor.
/// The desired security options can be set on the [SecurityContext] object.
///
/// ## Headers
///
/// All HttpClient requests set the following header by default:
///
///     Accept-Encoding: gzip
///
/// This allows the HTTP server to use gzip compression for the body if
/// possible. If this behavior is not desired set the
/// `Accept-Encoding` header to something else.
/// To turn off gzip compression of the response, clear this header:
///
///      request.headers.removeAll(HttpHeaders.acceptEncodingHeader)
///
/// ## Closing the HttpClient
///
/// The HttpClient supports persistent connections and caches network
/// connections to reuse them for multiple requests whenever
/// possible. This means that network connections can be kept open for
/// some time after a request has completed. Use HttpClient.close
/// to force the HttpClient object to shut down and to close the idle
/// network connections.
///
/// ## Turning proxies on and off
///
/// By default the HttpClient uses the proxy configuration available
/// from the environment, see [findProxyFromEnvironment]. To turn off
/// the use of proxies set the [findProxy] property to
/// `null`.
///
///     HttpClient client = HttpClient();
///     client.findProxy = null;
abstract class HttpClient {
  static const int defaultHttpPort = 80;
  @Deprecated('Use defaultHttpPort instead')
  static const int DEFAULT_HTTP_PORT = defaultHttpPort;

  static const int defaultHttpsPort = 443;
  @Deprecated('Use defaultHttpsPort instead')
  static const int DEFAULT_HTTPS_PORT = defaultHttpsPort;

  /// Current state of HTTP request logging from all [HttpClient]s to the
  /// developer timeline.
  ///
  /// Default is `false`.
  static bool enableTimelineLogging = false;

  /// Gets and sets the idle timeout of non-active persistent (keep-alive)
  /// connections.
  ///
  /// The default value is 15 seconds.
  Duration idleTimeout = const Duration(seconds: 15);

  /// Gets and sets the connection timeout.
  ///
  /// When connecting to a new host exceeds this timeout, a [SocketException]
  /// is thrown. The timeout applies only to connections initiated after the
  /// timeout is set.
  ///
  /// When this is `null`, the OS default timeout is used. The default is
  /// `null`.
  Duration? connectionTimeout;

  /// Gets and sets the maximum number of live connections, to a single host.
  ///
  /// Increasing this number may lower performance and take up unwanted
  /// system resources.
  ///
  /// To disable, set to `null`.
  ///
  /// Default is `null`.
  int? maxConnectionsPerHost;

  /// Gets and sets whether the body of a response will be automatically
  /// uncompressed.
  ///
  /// The body of an HTTP response can be compressed. In most
  /// situations providing the un-compressed body is most
  /// convenient. Therefore the default behavior is to un-compress the
  /// body. However in some situations (e.g. implementing a transparent
  /// proxy) keeping the uncompressed stream is required.
  ///
  /// NOTE: Headers in the response are never modified. This means
  /// that when automatic un-compression is turned on the value of the
  /// header `Content-Length` will reflect the length of the original
  /// compressed body. Likewise the header `Content-Encoding` will also
  /// have the original value indicating compression.
  ///
  /// NOTE: Automatic un-compression is only performed if the
  /// `Content-Encoding` header value is `gzip`.
  ///
  /// This value affects all responses produced by this client after the
  /// value is changed.
  ///
  /// To disable, set to `false`.
  ///
  /// Default is `true`.
  bool autoUncompress = true;

  /// Gets and sets the default value of the `User-Agent` header for all requests
  /// generated by this [HttpClient].
  ///
  /// The default value is `Dart/<version> (dart:io)`.
  ///
  /// If the userAgent is set to `null`, no default `User-Agent` header will be
  /// added to each request.
  String? userAgent;

  factory HttpClient({SecurityContext? context}) {
    var overrides = HttpOverrides.current;
    if (overrides == null) {
      return choose.newHttpClient();
    }
    return overrides.createHttpClient(context);
  }

  /// Sets the function to be called when a site is requesting
  /// authentication. The URL requested and the security realm from the
  /// server are passed in the arguments [url] and [realm].
  ///
  /// The function returns a [Future] which should complete when the
  /// authentication has been resolved. If credentials cannot be
  /// provided the [Future] should complete with `false`. If
  /// credentials are available the function should add these using
  /// [addCredentials] before completing the [Future] with the value
  /// `true`.
  ///
  /// If the [Future] completes with `true` the request will be retried
  /// using the updated credentials, however, the retried request will not
  /// carry the original request payload. Otherwise response processing will
  /// continue normally.
  ///
  /// If it is known that the remote server requires authentication for all
  /// requests, it is advisable to use [addCredentials] directly, or manually
  /// set the `'authorization'` header on the request to avoid the overhead
  /// of a failed request, or issues due to missing request payload on retried
  /// request.
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String realm) f);

  /// Sets the function to be called when a proxy is requesting
  /// authentication. Information on the proxy in use and the security
  /// realm for the authentication are passed in the arguments [host],
  /// [port] and [realm].
  ///
  /// The function returns a [Future] which should complete when the
  /// authentication has been resolved. If credentials cannot be
  /// provided the [Future] should complete with `false`. If
  /// credentials are available the function should add these using
  /// [addProxyCredentials] before completing the [Future] with the value
  /// `true`.
  ///
  /// If the [Future] completes with `true` the request will be retried
  /// using the updated credentials. Otherwise response processing will
  /// continue normally.
  set authenticateProxy(
      Future<bool> Function(String host, int port, String scheme, String realm)
          f);

  /// Sets a callback that will decide whether to accept a secure connection
  /// with a server certificate that cannot be authenticated by any of our
  /// trusted root certificates.
  ///
  /// When an secure HTTP request if made, using this HttpClient, and the
  /// server returns a server certificate that cannot be authenticated, the
  /// callback is called asynchronously with the [X509Certificate] object and
  /// the server's hostname and port.  If the value of [badCertificateCallback]
  /// is `null`, the bad certificate is rejected, as if the callback
  /// returned `false`
  ///
  /// If the callback returns true, the secure connection is accepted and the
  /// [:Future<HttpClientRequest>:] that was returned from the call making the
  /// request completes with a valid HttpRequest object. If the callback returns
  /// false, the [:Future<HttpClientRequest>:] completes with an exception.
  ///
  /// If a bad certificate is received on a connection attempt, the library calls
  /// the function that was the value of badCertificateCallback at the time
  /// the request is made, even if the value of badCertificateCallback
  /// has changed since then.
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port) callback);

  /// Sets the function used to resolve the proxy server to be used for
  /// opening a HTTP connection to the specified [url]. If this
  /// function is not set, direct connections will always be used.
  ///
  /// The string returned by [f] must be in the format used by browser
  /// PAC (proxy auto-config) scripts. That is either
  ///
  ///     "DIRECT"
  ///
  /// for using a direct connection or
  ///
  ///     "PROXY host:port"
  ///
  /// for using the proxy server `host` on port `port`.
  ///
  /// A configuration can contain several configuration elements
  /// separated by semicolons, e.g.
  ///
  ///     "PROXY host:port; PROXY host2:port2; DIRECT"
  ///
  /// The static function [findProxyFromEnvironment] on this class can
  /// be used to implement proxy server resolving based on environment
  /// variables.
  set findProxy(String Function(Uri url) f);

  /// Add credentials to be used for authorizing HTTP requests.
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials);

  /// Add credentials to be used for authorizing HTTP proxies.
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials);

  /// Shuts down the HTTP client.
  ///
  /// If [force] is `false` (the default) the [HttpClient] will be kept alive
  /// until all active connections are done. If [force] is `true` any active
  /// connections will be closed to immediately release all resources. These
  /// closed connections will receive an error event to indicate that the client
  /// was shut down. In both cases trying to establish a new connection after
  /// calling [close] will throw an exception.
  void close({bool force = false});

  /// Opens a HTTP connection using the DELETE method.
  ///
  /// The server is specified using [host] and [port], and the path
  /// (including a possible query) is specified using [path].
  ///
  /// See [open] for details.
  Future<HttpClientRequest> delete(String host, int port, String path);

  /// Opens a HTTP connection using the DELETE method.
  ///
  /// The URL to use is specified in [url].
  ///
  /// See [openUrl] for details.
  Future<HttpClientRequest> deleteUrl(Uri url);

  /// Opens a HTTP connection using the GET method.
  ///
  /// The server is specified using [host] and [port], and the path
  /// (including a possible query) is specified using
  /// [path].
  ///
  /// See [open] for details.
  Future<HttpClientRequest> get(String host, int port, String path);

  /// Opens a HTTP connection using the GET method.
  ///
  /// The URL to use is specified in [url].
  ///
  /// See [openUrl] for details.
  Future<HttpClientRequest> getUrl(Uri url);

  /// Opens a HTTP connection using the HEAD method.
  ///
  /// The server is specified using [host] and [port], and the path
  /// (including a possible query) is specified using [path].
  ///
  /// See [open] for details.
  Future<HttpClientRequest> head(String host, int port, String path);

  /// Opens a HTTP connection using the HEAD method.
  ///
  /// The URL to use is specified in [url].
  ///
  /// See [openUrl] for details.
  Future<HttpClientRequest> headUrl(Uri url);

  /// Opens a HTTP connection.
  ///
  /// The HTTP method to use is specified in [method], the server is
  /// specified using [host] and [port], and the path (including
  /// a possible query) is specified using [path].
  /// The path may also contain a URI fragment, which will be ignored.
  ///
  /// The `Host` header for the request will be set to the value [host]:[port]
  /// (if [host] is an IP address, it will still be used in the `Host` header).
  /// This can be overridden through the [HttpClientRequest] interface before
  /// the request is sent.
  ///
  /// For additional information on the sequence of events during an
  /// HTTP transaction, and the objects returned by the futures, see
  /// the overall documentation for the class [HttpClient].
  Future<HttpClientRequest> open(
      String method, String host, int port, String path);

  /// Opens a HTTP connection.
  ///
  /// The HTTP method is specified in [method] and the URL to use in
  /// [url].
  ///
  /// The `Host` header for the request will be set to the value
  /// [Uri.host]:[Uri.port] from [url] (if [url.host] is an IP address, it will
  /// still be used in the `Host` header). This can be overridden through the
  /// [HttpClientRequest] interface before the request is sent.
  ///
  /// For additional information on the sequence of events during an
  /// HTTP transaction, and the objects returned by the futures, see
  /// the overall documentation for the class [HttpClient].
  Future<HttpClientRequest> openUrl(String method, Uri url);

  /// Opens a HTTP connection using the PATCH method.
  ///
  /// The server is specified using [host] and [port], and the path
  /// (including a possible query) is specified using [path].
  ///
  /// See [open] for details.
  Future<HttpClientRequest> patch(String host, int port, String path);

  /// Opens a HTTP connection using the PATCH method.
  ///
  /// The URL to use is specified in [url].
  ///
  /// See [openUrl] for details.
  Future<HttpClientRequest> patchUrl(Uri url);

  /// Opens a HTTP connection using the POST method.
  ///
  /// The server is specified using [host] and [port], and the path
  /// (including a possible query) is specified using
  /// [path].
  ///
  /// See [open] for details.
  Future<HttpClientRequest> post(String host, int port, String path);

  /// Opens a HTTP connection using the POST method.
  ///
  /// The URL to use is specified in [url].
  ///
  /// See [openUrl] for details.
  Future<HttpClientRequest> postUrl(Uri url);

  /// Opens a HTTP connection using the PUT method.
  ///
  /// The server is specified using [host] and [port], and the path
  /// (including a possible query) is specified using [path].
  ///
  /// See [open] for details.
  Future<HttpClientRequest> put(String host, int port, String path);

  /// Opens a HTTP connection using the PUT method.
  ///
  /// The URL to use is specified in [url].
  ///
  /// See [openUrl] for details.
  Future<HttpClientRequest> putUrl(Uri url);

  /// Function for resolving the proxy server to be used for a HTTP
  /// connection from the proxy configuration specified through
  /// environment variables.
  ///
  /// The following environment variables are taken into account:
  ///
  ///     http_proxy
  ///     https_proxy
  ///     no_proxy
  ///     HTTP_PROXY
  ///     HTTPS_PROXY
  ///     NO_PROXY
  ///
  /// [:http_proxy:] and [:HTTP_PROXY:] specify the proxy server to use for
  /// http:// urls. Use the format [:hostname:port:]. If no port is used a
  /// default of 1080 will be used. If both are set the lower case one takes
  /// precedence.
  ///
  /// [:https_proxy:] and [:HTTPS_PROXY:] specify the proxy server to use for
  /// https:// urls. Use the format [:hostname:port:]. If no port is used a
  /// default of 1080 will be used. If both are set the lower case one takes
  /// precedence.
  ///
  /// [:no_proxy:] and [:NO_PROXY:] specify a comma separated list of
  /// postfixes of hostnames for which not to use the proxy
  /// server. E.g. the value "localhost,127.0.0.1" will make requests
  /// to both "localhost" and "127.0.0.1" not use a proxy. If both are set
  /// the lower case one takes precedence.
  ///
  /// To activate this way of resolving proxies assign this function to
  /// the [findProxy] property on the [HttpClient].
  ///
  ///     HttpClient client = HttpClient();
  ///     client.findProxy = HttpClient.findProxyFromEnvironment;
  ///
  /// If you don't want to use the system environment you can use a
  /// different one by wrapping the function.
  ///
  ///     HttpClient client = HttpClient();
  ///     client.findProxy = (url) {
  ///       return HttpClient.findProxyFromEnvironment(
  ///           url, environment: {"http_proxy": ..., "no_proxy": ...});
  ///     }
  ///
  /// If a proxy requires authentication it is possible to configure
  /// the username and password as well. Use the format
  /// [:username:password@hostname:port:] to include the username and
  /// password. Alternatively the API [addProxyCredentials] can be used
  /// to set credentials for proxies which require authentication.
  static String findProxyFromEnvironment(Uri url,
      {Map<String, String>? environment}) {
    final overrides = HttpOverrides.current;
    if (overrides == null) {
      return 'DIRECT';
    }
    return overrides.findProxyFromEnvironment(url, environment);
  }
}

/// Represents credentials for basic authentication.
abstract class HttpClientBasicCredentials extends HttpClientCredentials {
  factory HttpClientBasicCredentials(String username, String password) =>
      throw UnimplementedError();
}

abstract class HttpClientCredentials {}

/// Represents credentials for digest authentication. Digest
/// authentication is only supported for servers using the MD5
/// algorithm and quality of protection (qop) of either "none" or
/// "auth".
abstract class HttpClientDigestCredentials extends HttpClientCredentials {
  factory HttpClientDigestCredentials(String username, String password) =>
      throw UnimplementedError();
}

/// HTTP request for a client connection.
///
/// To set up a request, set the headers using the headers property
/// provided in this class and write the data to the body of the request.
/// HttpClientRequest is an [IOSink]. Use the methods from IOSink,
/// such as writeCharCode(), to write the body of the HTTP
/// request. When one of the IOSink methods is used for the first
/// time, the request header is sent. Calling any methods that
/// change the header after it is sent throws an exception.
///
/// When writing string data through the [IOSink] the
/// encoding used is determined from the "charset" parameter of
/// the "Content-Type" header.
///
///     HttpClientRequest request = ...
///     request.headers.contentType
///         = ContentType("application", "json", charset: "utf-8");
///     request.write(...);  // Strings written will be UTF-8 encoded.
///
/// If no charset is provided the default of ISO-8859-1 (Latin 1) is
/// be used.
///
///     HttpClientRequest request = ...
///     request.headers.add(HttpHeaders.contentTypeHeader, "text/plain");
///     request.write(...);  // Strings written will be ISO-8859-1 encoded.
///
/// An exception is thrown if you use an unsupported encoding and the
/// `write()` method being used takes a string parameter.
abstract class HttpClientRequest implements IOSink {
  /// The requested persistent connection state.
  ///
  /// The default value is `true`.
  bool persistentConnection = true;

  /// Whether to follow redirects automatically.
  ///
  /// Set this property to `false` if this request should not
  /// automatically follow redirects. The default is `true`.
  ///
  /// Automatic redirect will only happen for "GET" and "HEAD" requests
  /// and only for the status codes [HttpStatus.movedPermanently]
  /// (301), [HttpStatus.found] (302),
  /// [HttpStatus.movedTemporarily] (302, alias for
  /// [HttpStatus.found]), [HttpStatus.seeOther] (303),
  /// [HttpStatus.temporaryRedirect] (307) and
  /// [HttpStatus.permanentRedirect] (308). For
  /// [HttpStatus.seeOther] (303) automatic redirect will also happen
  /// for "POST" requests with the method changed to "GET" when
  /// following the redirect.
  ///
  /// All headers added to the request will be added to the redirection
  /// request(s). However, any body send with the request will not be
  /// part of the redirection request(s).
  bool followRedirects = true;

  /// Set this property to the maximum number of redirects to follow
  /// when [followRedirects] is `true`. If this number is exceeded
  /// an error event will be added with a [RedirectException].
  ///
  /// The default value is 5.
  int maxRedirects = 5;

  /// Gets and sets the content length of the request.
  ///
  /// If the size of the request is not known in advance set content length to
  /// -1, which is also the default.
  int contentLength = -1;

  /// Gets or sets if the [HttpClientRequest] should buffer output.
  ///
  /// Default value is `true`.
  ///
  /// __Note__: Disabling buffering of the output can result in very poor
  /// performance, when writing many small chunks.
  bool bufferOutput = true;

  /// Gets information about the client connection.
  ///
  /// Returns `null` if the socket is not available.
  HttpConnectionInfo? get connectionInfo;

  /// Cookies to present to the server (in the 'cookie' header).
  List<Cookie> get cookies;

  /// A [HttpClientResponse] future that will complete once the response is
  /// available.
  ///
  /// If an error occurs before the response is available, this future will
  /// complete with an error.
  @override
  Future<HttpClientResponse> get done;

  /// Returns the client request headers.
  ///
  /// The client request headers can be modified until the client
  /// request body is written to or closed. After that they become
  /// immutable.
  HttpHeaders get headers;

  /// The method of the request.
  String get method;

  /// The uri of the request.
  Uri get uri;

  /// Aborts the client connection.
  ///
  /// If the connection has not yet completed, the request is aborted and the
  /// [done] future (also returned by [close]) is completed with the provided
  /// [exception] and [stackTrace].
  /// If [exception] is omitted, it defaults to an [HttpException], and if
  /// [stackTrace] is omitted, it defaults to [StackTrace.empty].
  ///
  /// If the [done] future has already completed, aborting has no effect.
  ///
  /// Using the [IOSink] methods (e.g., [write] and [add]) has no effect after
  /// the request has been aborted
  ///
  /// ```dart
  /// HttpClientRequst request = ...
  /// request.write();
  /// Timer(Duration(seconds: 1), () {
  ///   request.abort();
  /// });
  /// request.close().then((response) {
  ///   // If response comes back before abort, this callback will be called.
  /// }, onError: (e) {
  ///   // If abort() called before response is available, onError will fire.
  /// });
  /// ```
  @Since('2.10')
  void abort([Object? exception, StackTrace? stackTrace]);

  /// Close the request for input. Returns the value of [done].
  @override
  Future<HttpClientResponse> close();
}

/// HTTP response for a client connection.
///
/// The body of a [HttpClientResponse] object is a
/// [Stream] of data from the server. Listen to the body to handle
/// the data and be notified when the entire body is received.
///
///     new HttpClient().get('localhost', 80, '/file.txt')
///          .then((HttpClientRequest request) => request.close())
///          .then((HttpClientResponse response) {
///            response.transform(utf8.decoder).listen((contents) {
///              // handle data
///            });
///          });
abstract class HttpClientResponse implements Stream<List<int>> {
  /// Returns the certificate of the HTTPS server providing the response.
  /// Returns null if the connection is not a secure TLS or SSL connection.
  X509Certificate? get certificate;

  /// The compression state of the response.
  ///
  /// This specifies whether the response bytes were compressed when they were
  /// received across the wire and whether callers will receive compressed
  /// or uncompressed bytes when they listed to this response's byte stream.
  @Since('2.4')
  HttpClientResponseCompressionState get compressionState;

  /// Gets information about the client connection. Returns `null` if the socket
  /// is not available.
  HttpConnectionInfo? get connectionInfo;

  /// Returns the content length of the response body. Returns -1 if the size of
  /// the response body is not known in advance.
  ///
  /// If the content length needs to be set, it must be set before the
  /// body is written to. Setting the content length after writing to the body
  /// will throw a `StateError`.
  int get contentLength;

  /// Cookies set by the server (from the 'set-cookie' header).
  List<Cookie> get cookies;

  /// Returns the client response headers.
  ///
  /// The client response headers are immutable.
  HttpHeaders get headers;

  /// Returns whether the status code is one of the normal redirect
  /// codes [HttpStatus.movedPermanently], [HttpStatus.found],
  /// [HttpStatus.movedTemporarily], [HttpStatus.seeOther] and
  /// [HttpStatus.temporaryRedirect].
  bool get isRedirect;

  /// Gets the persistent connection state returned by the server.
  ///
  /// If the persistent connection state needs to be set, it must be
  /// set before the body is written to. Setting the persistent connection state
  /// after writing to the body will throw a `StateError`.
  bool get persistentConnection;

  /// Returns the reason phrase associated with the status code.
  ///
  /// The reason phrase must be set before the body is written
  /// to. Setting the reason phrase after writing to the body will throw
  /// a `StateError`.
  String get reasonPhrase;

  /// Returns the series of redirects this connection has been through. The
  /// list will be empty if no redirects were followed. [redirects] will be
  /// updated both in the case of an automatic and a manual redirect.
  List<RedirectInfo> get redirects;

  /// Returns the status code.
  ///
  /// The status code must be set before the body is written
  /// to. Setting the status code after writing to the body will throw
  /// a `StateError`.
  int get statusCode;

  /// Detach the underlying socket from the HTTP client. When the
  /// socket is detached the HTTP client will no longer perform any
  /// operations on it.
  ///
  /// This is normally used when a HTTP upgrade is negotiated and the
  /// communication should continue with a different protocol.
  Future<Socket> detachSocket();

  /// Redirects this connection to a new URL. The default value for
  /// [method] is the method for the current request. The default value
  /// for [url] is the value of the [HttpHeaders.locationHeader] header of
  /// the current response. All body data must have been read from the
  /// current response before calling [redirect].
  ///
  /// All headers added to the request will be added to the redirection
  /// request. However, any body sent with the request will not be
  /// part of the redirection request.
  ///
  /// If [followLoops] is set to `true`, redirect will follow the redirect,
  /// even if the URL was already visited. The default value is `false`.
  ///
  /// The method will ignore [HttpClientRequest.maxRedirects]
  /// and will always perform the redirect.
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]);
}

/// Enum that specifies the compression state of the byte stream of an
/// [HttpClientResponse].
///
/// The values herein allow callers to answer the following questions as they
/// pertain to an [HttpClientResponse]:
///
///  * Can the value of the response's `Content-Length` HTTP header be trusted?
///  * Does the caller need to manually decompress the response's byte stream?
///
/// This enum is accessed via the [HttpClientResponse.compressionState] value.
@Since('2.4')
enum HttpClientResponseCompressionState {
  /// The body of the HTTP response was received and remains in an uncompressed
  /// state.
  ///
  /// In this state, the value of the `Content-Length` HTTP header, if
  /// specified (non-negative), should match the number of bytes produced by
  /// the response's byte stream.
  notCompressed,

  /// The body of the HTTP response was originally compressed, but by virtue of
  /// the [HttpClient.autoUncompress] configuration option, it has been
  /// automatically uncompressed.
  ///
  /// HTTP headers are not modified, so when a response has been uncompressed
  /// in this way, the value of the `Content-Length` HTTP header cannot be
  /// trusted, as it will contain the compressed content length, whereas the
  /// stream of bytes produced by the response will contain uncompressed bytes.
  decompressed,

  /// The body of the HTTP response contains compressed bytes.
  ///
  /// In this state, the value of the `Content-Length` HTTP header, if
  /// specified (non-negative), should match the number of bytes produced by
  /// the response's byte stream.
  ///
  /// If the caller wishes to manually uncompress the body of the response,
  /// it should consult the value of the `Content-Encoding` HTTP header to see
  /// what type of compression has been applied. See
  /// <https://tools.ietf.org/html/rfc2616#section-14.11> for more information.
  compressed,
}

/// Information about an [HttpRequest], [HttpResponse], [HttpClientRequest], or
/// [HttpClientResponse] connection.
abstract class HttpConnectionInfo {
  int get localPort;

  InternetAddress get remoteAddress;

  int get remotePort;
}

/// Summary statistics about an [HttpServer]s current socket connections.
class HttpConnectionsInfo {
  /// Total number of socket connections.
  int total = 0;

  /// Number of active connections where actual request/response
  /// processing is active.
  int active = 0;

  /// Number of idle connections held by clients as persistent connections.
  int idle = 0;

  /// Number of connections which are preparing to close.
  ///
  /// Note: These connections are also part of the [active] count as they might
  /// still be sending data to the client before finally closing.
  int closing = 0;
}

class HttpException implements IOException {
  final String message;
  final Uri? uri;

  const HttpException(this.message, {this.uri});

  @override
  String toString() {
    var b = StringBuffer()..write('HttpException: ')..write(message);
    var uri = this.uri;
    if (uri != null) {
      b.write(', uri = $uri');
    }
    return b.toString();
  }
}

/// Headers for HTTP requests and responses.
///
///
/// * [HttpRequest] and [HttpClientResponse] always have immutable headers.
///
/// * [HttpResponse] and [HttpClientRequest] have immutable headers
///   from the moment the body is written to.
///
/// In these situations, the mutating methods throw exceptions.
///
/// For all operations on HTTP headers the header name is
/// case-insensitive.
///
/// To set the value of a header use the `set()` method:
///
///     request.headers.set(HttpHeaders.cacheControlHeader,
///                         'max-age=3600, must-revalidate');
///
/// To retrieve the value of a header use the `value()` method:
///
///     print(request.headers.value(HttpHeaders.userAgentHeader));
///
/// An `HttpHeaders` object holds a list of values for each name
/// as the standard allows. In most cases a name holds only a single value,
/// The most common mode of operation is to use `set()` for setting a value,
/// and `value()` for retrieving a value.
abstract class HttpHeaders {
  static const acceptHeader = 'accept';
  static const acceptCharsetHeader = 'accept-charset';
  static const acceptEncodingHeader = 'accept-encoding';
  static const acceptLanguageHeader = 'accept-language';
  static const acceptRangesHeader = 'accept-ranges';
  static const ageHeader = 'age';
  static const allowHeader = 'allow';
  static const authorizationHeader = 'authorization';
  static const cacheControlHeader = 'cache-control';
  static const connectionHeader = 'connection';
  static const contentEncodingHeader = 'content-encoding';
  static const contentLanguageHeader = 'content-language';
  static const contentLengthHeader = 'content-length';
  static const contentLocationHeader = 'content-location';
  static const contentMD5Header = 'content-md5';
  static const contentRangeHeader = 'content-range';
  static const contentTypeHeader = 'content-type';
  static const dateHeader = 'date';
  static const etagHeader = 'etag';
  static const expectHeader = 'expect';
  static const expiresHeader = 'expires';
  static const fromHeader = 'from';
  static const hostHeader = 'host';
  static const ifMatchHeader = 'if-match';
  static const ifModifiedSinceHeader = 'if-modified-since';
  static const ifNoneMatchHeader = 'if-none-match';
  static const ifRangeHeader = 'if-range';
  static const ifUnmodifiedSinceHeader = 'if-unmodified-since';
  static const lastModifiedHeader = 'last-modified';
  static const locationHeader = 'location';
  static const maxForwardsHeader = 'max-forwards';
  static const pragmaHeader = 'pragma';
  static const proxyAuthenticateHeader = 'proxy-authenticate';
  static const proxyAuthorizationHeader = 'proxy-authorization';
  static const rangeHeader = 'range';
  static const refererHeader = 'referer';
  static const retryAfterHeader = 'retry-after';
  static const serverHeader = 'server';
  static const teHeader = 'te';
  static const trailerHeader = 'trailer';
  static const transferEncodingHeader = 'transfer-encoding';
  static const upgradeHeader = 'upgrade';
  static const userAgentHeader = 'user-agent';
  static const varyHeader = 'vary';
  static const viaHeader = 'via';
  static const warningHeader = 'warning';
  static const wwwAuthenticateHeader = 'www-authenticate';

  @Deprecated('Use acceptHeader instead')
  static const ACCEPT = acceptHeader;
  @Deprecated('Use acceptCharsetHeader instead')
  static const ACCEPT_CHARSET = acceptCharsetHeader;
  @Deprecated('Use acceptEncodingHeader instead')
  static const ACCEPT_ENCODING = acceptEncodingHeader;
  @Deprecated('Use acceptLanguageHeader instead')
  static const ACCEPT_LANGUAGE = acceptLanguageHeader;
  @Deprecated('Use acceptRangesHeader instead')
  static const ACCEPT_RANGES = acceptRangesHeader;
  @Deprecated('Use ageHeader instead')
  static const AGE = ageHeader;
  @Deprecated('Use allowHeader instead')
  static const ALLOW = allowHeader;
  @Deprecated('Use authorizationHeader instead')
  static const AUTHORIZATION = authorizationHeader;
  @Deprecated('Use cacheControlHeader instead')
  static const CACHE_CONTROL = cacheControlHeader;
  @Deprecated('Use connectionHeader instead')
  static const CONNECTION = connectionHeader;
  @Deprecated('Use contentEncodingHeader instead')
  static const CONTENT_ENCODING = contentEncodingHeader;
  @Deprecated('Use contentLanguageHeader instead')
  static const CONTENT_LANGUAGE = contentLanguageHeader;
  @Deprecated('Use contentLengthHeader instead')
  static const CONTENT_LENGTH = contentLengthHeader;
  @Deprecated('Use contentLocationHeader instead')
  static const CONTENT_LOCATION = contentLocationHeader;
  @Deprecated('Use contentMD5Header instead')
  static const CONTENT_MD5 = contentMD5Header;
  @Deprecated('Use contentRangeHeader instead')
  static const CONTENT_RANGE = contentRangeHeader;
  @Deprecated('Use contentTypeHeader instead')
  static const CONTENT_TYPE = contentTypeHeader;
  @Deprecated('Use dateHeader instead')
  static const DATE = dateHeader;
  @Deprecated('Use etagHeader instead')
  static const ETAG = etagHeader;
  @Deprecated('Use expectHeader instead')
  static const EXPECT = expectHeader;
  @Deprecated('Use expiresHeader instead')
  static const EXPIRES = expiresHeader;
  @Deprecated('Use fromHeader instead')
  static const FROM = fromHeader;
  @Deprecated('Use hostHeader instead')
  static const HOST = hostHeader;
  @Deprecated('Use ifMatchHeader instead')
  static const IF_MATCH = ifMatchHeader;
  @Deprecated('Use ifModifiedSinceHeader instead')
  static const IF_MODIFIED_SINCE = ifModifiedSinceHeader;
  @Deprecated('Use ifNoneMatchHeader instead')
  static const IF_NONE_MATCH = ifNoneMatchHeader;
  @Deprecated('Use ifRangeHeader instead')
  static const IF_RANGE = ifRangeHeader;
  @Deprecated('Use ifUnmodifiedSinceHeader instead')
  static const IF_UNMODIFIED_SINCE = ifUnmodifiedSinceHeader;
  @Deprecated('Use lastModifiedHeader instead')
  static const LAST_MODIFIED = lastModifiedHeader;
  @Deprecated('Use locationHeader instead')
  static const LOCATION = locationHeader;
  @Deprecated('Use maxForwardsHeader instead')
  static const MAX_FORWARDS = maxForwardsHeader;
  @Deprecated('Use pragmaHeader instead')
  static const PRAGMA = pragmaHeader;
  @Deprecated('Use proxyAuthenticateHeader instead')
  static const PROXY_AUTHENTICATE = proxyAuthenticateHeader;
  @Deprecated('Use proxyAuthorizationHeader instead')
  static const PROXY_AUTHORIZATION = proxyAuthorizationHeader;
  @Deprecated('Use rangeHeader instead')
  static const RANGE = rangeHeader;
  @Deprecated('Use refererHeader instead')
  static const REFERER = refererHeader;
  @Deprecated('Use retryAfterHeader instead')
  static const RETRY_AFTER = retryAfterHeader;
  @Deprecated('Use serverHeader instead')
  static const SERVER = serverHeader;
  @Deprecated('Use teHeader instead')
  static const TE = teHeader;
  @Deprecated('Use trailerHeader instead')
  static const TRAILER = trailerHeader;
  @Deprecated('Use transferEncodingHeader instead')
  static const TRANSFER_ENCODING = transferEncodingHeader;
  @Deprecated('Use upgradeHeader instead')
  static const UPGRADE = upgradeHeader;
  @Deprecated('Use userAgentHeader instead')
  static const USER_AGENT = userAgentHeader;
  @Deprecated('Use varyHeader instead')
  static const VARY = varyHeader;
  @Deprecated('Use viaHeader instead')
  static const VIA = viaHeader;
  @Deprecated('Use warningHeader instead')
  static const WARNING = warningHeader;
  @Deprecated('Use wwwAuthenticateHeader instead')
  static const WWW_AUTHENTICATE = wwwAuthenticateHeader;

  // Cookie headers from RFC 6265.
  static const cookieHeader = 'cookie';
  static const setCookieHeader = 'set-cookie';

  @Deprecated('Use cookieHeader instead')
  static const COOKIE = cookieHeader;
  @Deprecated('Use setCookieHeader instead')
  static const SET_COOKIE = setCookieHeader;

  // TODO(39783): Document this.
  static const generalHeaders = [
    cacheControlHeader,
    connectionHeader,
    dateHeader,
    pragmaHeader,
    trailerHeader,
    transferEncodingHeader,
    upgradeHeader,
    viaHeader,
    warningHeader
  ];

  @Deprecated('Use generalHeaders instead')
  static const GENERAL_HEADERS = generalHeaders;

  static const entityHeaders = [
    allowHeader,
    contentEncodingHeader,
    contentLanguageHeader,
    contentLengthHeader,
    contentLocationHeader,
    contentMD5Header,
    contentRangeHeader,
    contentTypeHeader,
    expiresHeader,
    lastModifiedHeader
  ];

  @Deprecated('Use entityHeaders instead')
  static const ENTITY_HEADERS = entityHeaders;

  static const responseHeaders = [
    acceptRangesHeader,
    ageHeader,
    etagHeader,
    locationHeader,
    proxyAuthenticateHeader,
    retryAfterHeader,
    serverHeader,
    varyHeader,
    wwwAuthenticateHeader
  ];

  @Deprecated('Use responseHeaders instead')
  static const RESPONSE_HEADERS = responseHeaders;

  static const requestHeaders = [
    acceptHeader,
    acceptCharsetHeader,
    acceptEncodingHeader,
    acceptLanguageHeader,
    authorizationHeader,
    expectHeader,
    fromHeader,
    hostHeader,
    ifMatchHeader,
    ifModifiedSinceHeader,
    ifNoneMatchHeader,
    ifRangeHeader,
    ifUnmodifiedSinceHeader,
    maxForwardsHeader,
    proxyAuthorizationHeader,
    rangeHeader,
    refererHeader,
    teHeader,
    userAgentHeader
  ];

  @Deprecated('Use requestHeaders instead')
  static const REQUEST_HEADERS = requestHeaders;

  /// The date specified by the [dateHeader] header, if any.
  DateTime? date;

  /// The date and time specified by the [expiresHeader] header, if any.
  DateTime? expires;

  /// The date and time specified by the [ifModifiedSinceHeader] header, if any.
  DateTime? ifModifiedSince;

  /// The value of the [hostHeader] header, if any.
  String? host;

  /// The value of the port part of the [hostHeader] header, if any.
  int? port;

  /// The [ContentType] of the [contentTypeHeader] header, if any.
  ContentType? contentType;

  /// The value of the [contentLengthHeader] header, if any.
  ///
  /// The value is negative if there is no content length set.
  int contentLength = -1;

  /// Whether the connection is persistent (keep-alive).
  late bool persistentConnection;

  /// Whether the connection uses chunked transfer encoding.
  ///
  /// Reflects and modifies the value of the [transferEncodingHeader] header.
  late bool chunkedTransferEncoding;

  /// The values for the header named [name].
  ///
  /// Returns null if there is no header with the provided name,
  /// otherwise returns a new list containing the current values.
  /// Not that modifying the list does not change the header.
  List<String>? operator [](String name);

  /// Adds a header value.
  ///
  /// The header named [name] will have a string value derived from [value]
  /// added to its list of values.
  ///
  /// Some headers are single valued, and for these, adding a value will
  /// replace a previous value. If the [value] is a [DateTime], an
  /// HTTP date format will be applied. If the value is an [Iterable],
  /// each element will be added separately. For all other
  /// types the default [Object.toString] method will be used.
  ///
  /// Header names are converted to lower-case unless
  /// [preserveHeaderCase] is set to true. If two header names are
  /// the same when converted to lower-case, they are considered to be
  /// the same header, with one set of values.
  ///
  /// The current case of the a header name is that of the name used by
  /// the last [set] or [add] call for that header.
  void add(String name, Object value,
      {@Since('2.8') bool preserveHeaderCase = false});

  /// Removes all headers.
  ///
  /// Some headers have system supplied values which cannot be removed.
  /// All other header values are removed, and header names with not
  /// remaining values are no longer considered present.
  void clear();

  /// Performs the [action] on each header.
  ///
  /// The [action] function is called with each header's name and a list
  /// of the header's values. The casing of the name string is determined by
  /// the last [add] or [set] operation for that particular header,
  /// which defaults to lower-casing the header name unless explicitly
  /// set to preserve the case.
  void forEach(void Function(String name, List<String> values) action);

  /// Disables folding for the header named [name] when sending the HTTP header.
  ///
  /// By default, multiple header values are folded into a
  /// single header line by separating the values with commas.
  ///
  /// The 'set-cookie' header has folding disabled by default.
  void noFolding(String name);

  /// Removes a specific value for a header name.
  ///
  /// Some headers have system supplied values which cannot be removed.
  /// For all other headers and values, the [value] is converted to a string
  /// in the same way as for [add], then that string value is removed from the
  /// current values of [name].
  /// If there are no remaining values for [name], the header is no longer
  /// considered present.
  void remove(String name, Object value);

  /// Removes all values for the specified header name.
  ///
  /// Some headers have system supplied values which cannot be removed.
  /// All other values for [name] are removed.
  /// If there are no remaining values for [name], the header is no longer
  /// considered present.
  void removeAll(String name);

  /// Sets the header [name] to [value].
  ///
  /// Removes all existing values for the header named [name] and
  /// then [add]s [value] to it.
  void set(String name, Object value,
      {@Since('2.8') bool preserveHeaderCase = false});

  /// Convenience method for the value for a single valued header.
  ///
  /// The value must not have more than one value.
  ///
  /// Returns `null` if there is no header with the provided name.
  String? value(String name);
}

/// A server-side object
/// that contains the content of and information about an HTTP request.
///
/// __Note__: Check out the
/// [http_server](https://pub.dev/packages/http_server)
/// package, which makes working with the low-level
/// dart:io HTTP server subsystem easier.
///
/// `HttpRequest` objects are generated by an [HttpServer],
/// which listens for HTTP requests on a specific host and port.
/// For each request received, the HttpServer, which is a [Stream],
/// generates an `HttpRequest` object and adds it to the stream.
///
/// An `HttpRequest` object delivers the body content of the request
/// as a stream of byte lists.
/// The object also contains information about the request,
/// such as the method, URI, and headers.
///
/// In the following code, an HttpServer listens
/// for HTTP requests. When the server receives a request,
/// it uses the HttpRequest object's `method` property to dispatch requests.
///
///     final HOST = InternetAddress.loopbackIPv4;
///     final PORT = 80;
///
///     HttpServer.bind(HOST, PORT).then((_server) {
///       _server.listen((HttpRequest request) {
///         switch (request.method) {
///           case 'GET':
///             handleGetRequest(request);
///             break;
///           case 'POST':
///             ...
///         }
///       },
///       onError: handleError);    // listen() failed.
///     }).catchError(handleError);
///
/// An HttpRequest object provides access to the associated [HttpResponse]
/// object through the response property.
/// The server writes its response to the body of the HttpResponse object.
/// For example, here's a function that responds to a request:
///
///     void handleGetRequest(HttpRequest req) {
///       HttpResponse res = req.response;
///       res.write('Received request ${req.method}: ${req.uri.path}');
///       res.close();
///     }
abstract class HttpRequest implements Stream<Uint8List> {
  /// The client certificate of the client making the request.
  ///
  /// This value is null if the connection is not a secure TLS or SSL connection,
  /// or if the server does not request a client certificate, or if the client
  /// does not provide one.
  X509Certificate? get certificate;

  /// Information about the client connection.
  ///
  /// Returns `null` if the socket is not available.
  HttpConnectionInfo? get connectionInfo;

  /// The content length of the request body.
  ///
  /// If the size of the request body is not known in advance,
  /// this value is -1.
  int get contentLength;

  /// The cookies in the request, from the "Cookie" headers.
  List<Cookie> get cookies;

  /// The request headers.
  ///
  /// The returned [HttpHeaders] are immutable.
  HttpHeaders get headers;

  /// The method, such as 'GET' or 'POST', for the request.
  String get method;

  /// The persistent connection state signaled by the client.
  bool get persistentConnection;

  /// The HTTP protocol version used in the request,
  /// either "1.0" or "1.1".
  String get protocolVersion;

  /// The requested URI for the request.
  ///
  /// The returned URI is reconstructed by using http-header fields, to access
  /// otherwise lost information, e.g. host and scheme.
  ///
  /// To reconstruct the scheme, first 'X-Forwarded-Proto' is checked, and then
  /// falling back to server type.
  ///
  /// To reconstruct the host, first 'X-Forwarded-Host' is checked, then 'Host'
  /// and finally calling back to server.
  Uri get requestedUri;

  /// The [HttpResponse] object, used for sending back the response to the
  /// client.
  ///
  /// If the [contentLength] of the body isn't 0, and the body isn't being read,
  /// any write calls on the [HttpResponse] automatically drain the request
  /// body.
  HttpResponse get response;

  /// The session for the given request.
  ///
  /// If the session is being initialized by this call,
  /// [HttpSession.isNew] is true for the returned session.
  /// See [HttpServer.sessionTimeout] on how to change default timeout.
  HttpSession get session;

  /// The URI for the request.
  ///
  /// This provides access to the
  /// path and query string for the request.
  Uri get uri;
}

/// An HTTP response, which returns the headers and data
/// from the server to the client in response to an HTTP request.
///
/// Every HttpRequest object provides access to the associated [HttpResponse]
/// object through the `response` property.
/// The server sends its response to the client by writing to the
/// HttpResponse object.
///
/// ## Writing the response
///
/// This class implements [IOSink].
/// After the header has been set up, the methods
/// from IOSink, such as `writeln()`, can be used to write
/// the body of the HTTP response.
/// Use the `close()` method to close the response and send it to the client.
///
///     server.listen((HttpRequest request) {
///       request.response.write('Hello, world!');
///       request.response.close();
///     });
///
/// When one of the IOSink methods is used for the
/// first time, the request header is sent. Calling any methods that
/// change the header after it is sent throws an exception.
///
/// ## Setting the headers
///
/// The HttpResponse object has a number of properties for setting up
/// the HTTP headers of the response.
/// When writing string data through the IOSink, the encoding used
/// is determined from the "charset" parameter of the
/// "Content-Type" header.
///
///     HttpResponse response = ...
///     response.headers.contentType
///         = ContentType("application", "json", charset: "utf-8");
///     response.write(...);  // Strings written will be UTF-8 encoded.
///
/// If no charset is provided the default of ISO-8859-1 (Latin 1) will
/// be used.
///
///     HttpResponse response = ...
///     response.headers.add(HttpHeaders.contentTypeHeader, "text/plain");
///     response.write(...);  // Strings written will be ISO-8859-1 encoded.
///
/// An exception is thrown if you use the `write()` method
/// while an unsupported content-type is set.
abstract class HttpResponse implements IOSink {
  // TODO(ajohnsen): Add documentation of how to pipe a file to the response.
  /// Gets and sets the content length of the response. If the size of
  /// the response is not known in advance set the content length to
  /// -1, which is also the default if not set.
  int contentLength = -1;

  /// The status code of the response.
  ///
  /// Any integer value is accepted. For
  /// the official HTTP status codes use the fields from
  /// [HttpStatus]. If no status code is explicitly set the default
  /// value [HttpStatus.ok] is used.
  ///
  /// The status code must be set before the body is written
  /// to. Setting the status code after writing to the response body or
  /// closing the response will throw a `StateError`.
  int statusCode = HttpStatus.ok;

  /// The reason phrase for the response.
  ///
  /// If no reason phrase is explicitly set, a default reason phrase is provided.
  ///
  /// The reason phrase must be set before the body is written
  /// to. Setting the reason phrase after writing to the response body
  /// or closing the response will throw a [StateError].
  late String reasonPhrase;

  /// Gets and sets the persistent connection state. The initial value
  /// of this property is the persistent connection state from the
  /// request.
  late bool persistentConnection;

  /// Set and get the [deadline] for the response. The deadline is timed from the
  /// time it's set. Setting a new deadline will override any previous deadline.
  /// When a deadline is exceeded, the response will be closed and any further
  /// data ignored.
  ///
  /// To disable a deadline, set the [deadline] to `null`.
  ///
  /// The [deadline] is `null` by default.
  Duration? deadline;

  /// Gets or sets if the [HttpResponse] should buffer output.
  ///
  /// Default value is `true`.
  ///
  /// __Note__: Disabling buffering of the output can result in very poor
  /// performance, when writing many small chunks.
  bool bufferOutput = true;

  /// Gets information about the client connection. Returns `null` if the
  /// socket is not available.
  HttpConnectionInfo? get connectionInfo;

  /// Cookies to set in the client (in the 'set-cookie' header).
  List<Cookie> get cookies;

  /// Returns the response headers.
  ///
  /// The response headers can be modified until the response body is
  /// written to or closed. After that they become immutable.
  HttpHeaders get headers;

  /// Detaches the underlying socket from the HTTP server. When the
  /// socket is detached the HTTP server will no longer perform any
  /// operations on it.
  ///
  /// This is normally used when a HTTP upgrade request is received
  /// and the communication should continue with a different protocol.
  ///
  /// If [writeHeaders] is `true`, the status line and [headers] will be written
  /// to the socket before it's detached. If `false`, the socket is detached
  /// immediately, without any data written to the socket. Default is `true`.
  Future<Socket> detachSocket({bool writeHeaders = true});

  /// Respond with a redirect to [location].
  ///
  /// The URI in [location] should be absolute, but there are no checks
  /// to enforce that.
  ///
  /// By default the HTTP status code `HttpStatus.movedTemporarily`
  /// (`302`) is used for the redirect, but an alternative one can be
  /// specified using the [status] argument.
  ///
  /// This method will also call `close`, and the returned future is
  /// the future returned by `close`.
  Future redirect(Uri location, {int status = HttpStatus.movedTemporarily});
}

/// A server that delivers content, such as web pages, using the HTTP protocol.
///
/// The HttpServer is a [Stream] that provides [HttpRequest] objects. Each
/// HttpRequest has an associated [HttpResponse] object.
/// The server responds to a request by writing to that HttpResponse object.
/// The following example shows how to bind an HttpServer to an IPv6
/// [InternetAddress] on port 80 (the standard port for HTTP servers)
/// and how to listen for requests.
/// Port 80 is the default HTTP port. However, on most systems accessing
/// this requires super-user privileges. For local testing consider
/// using a non-reserved port (1024 and above).
///
///     import 'dart:io';
///
///     main() {
///       HttpServer
///           .bind(InternetAddress.anyIPv6, 80)
///           .then((server) {
///             server.listen((HttpRequest request) {
///               request.response.write('Hello, world!');
///               request.response.close();
///             });
///           });
///     }
///
/// Incomplete requests, in which all or part of the header is missing, are
/// ignored, and no exceptions or HttpRequest objects are generated for them.
/// Likewise, when writing to an HttpResponse, any [Socket] exceptions are
/// ignored and any future writes are ignored.
///
/// The HttpRequest exposes the request headers and provides the request body,
/// if it exists, as a Stream of data. If the body is unread, it is drained
/// when the server writes to the HttpResponse or closes it.
///
/// ## Bind with a secure HTTPS connection
///
/// Use [bindSecure] to create an HTTPS server.
///
/// The server presents a certificate to the client. The certificate
/// chain and the private key are set in the [SecurityContext]
/// object that is passed to [bindSecure].
///
///     import 'dart:io';
///     import "dart:isolate";
///
///     main() {
///       SecurityContext context = SecurityContext();
///       var chain =
///           Platform.script.resolve('certificates/server_chain.pem')
///           .toFilePath();
///       var key =
///           Platform.script.resolve('certificates/server_key.pem')
///           .toFilePath();
///       context.useCertificateChain(chain);
///       context.usePrivateKey(key, password: 'dartdart');
///
///       HttpServer
///           .bindSecure(InternetAddress.anyIPv6,
///                       443,
///                       context)
///           .then((server) {
///             server.listen((HttpRequest request) {
///               request.response.write('Hello, world!');
///               request.response.close();
///             });
///           });
///     }
///
///  The certificates and keys are PEM files, which can be created and
///  managed with the tools in OpenSSL.
///
/// ## Connect to a server socket
///
/// You can use the [listenOn] constructor to attach an HTTP server to
/// a [ServerSocket].
///
///     import 'dart:io';
///
///     main() {
///       ServerSocket.bind(InternetAddress.anyIPv6, 80)
///         .then((serverSocket) {
///           HttpServer httpserver = HttpServer.listenOn(serverSocket);
///           serverSocket.listen((Socket socket) {
///             socket.write('Hello, client.');
///           });
///         });
///     }
///
/// ## Other resources
///
/// * HttpServer is a Stream. Refer to the [Stream] class for information
/// about the streaming qualities of an HttpServer.
/// Pausing the subscription of the stream, pauses at the OS level.
///
/// * The [shelf](https://pub.dev/packages/shelf)
/// package on pub.dev contains a set of high-level classes that,
/// together with this class, makes it easy to provide content through HTTP
/// servers.
abstract class HttpServer implements Stream<HttpRequest> {
  /// Gets and sets the default value of the `Server` header for all responses
  /// generated by this [HttpServer].
  ///
  /// If [serverHeader] is `null`, no `Server` header will be added to each
  /// response.
  ///
  /// The default value is `null`.
  String? serverHeader;

  /// Whether the [HttpServer] should compress the content, if possible.
  ///
  /// The content can only be compressed when the response is using
  /// chunked Transfer-Encoding and the incoming request has `gzip`
  /// as an accepted encoding in the Accept-Encoding header.
  ///
  /// The default value is `false` (compression disabled).
  /// To enable, set `autoCompress` to `true`.
  bool autoCompress = false;

  /// Gets or sets the timeout used for idle keep-alive connections. If no
  /// further request is seen within [idleTimeout] after the previous request was
  /// completed, the connection is dropped.
  ///
  /// Default is 120 seconds.
  ///
  /// Note that it may take up to `2 * idleTimeout` before a idle connection is
  /// aborted.
  ///
  /// To disable, set [idleTimeout] to `null`.
  Duration? idleTimeout = const Duration(seconds: 120);

  /// Attaches the HTTP server to an existing [ServerSocket]. When the
  /// [HttpServer] is closed, the [HttpServer] will just detach itself,
  /// closing current connections but not closing [serverSocket].
  factory HttpServer.listenOn(ServerSocket serverSocket) =>
      throw UnimplementedError();

  /// The address that the server is listening on.
  ///
  /// This is the actual address used when the original address
  /// was specified as a hostname.
  InternetAddress get address;

  /// Default set of headers added to all response objects.
  ///
  /// By default the following headers are in this set:
  ///
  ///     Content-Type: text/plain; charset=utf-8
  ///     X-Frame-Options: SAMEORIGIN
  ///     X-Content-Type-Options: nosniff
  ///     X-XSS-Protection: 1; mode=block
  ///
  /// If the `Server` header is added here and the `serverHeader` is set as
  /// well then the value of `serverHeader` takes precedence.
  HttpHeaders get defaultResponseHeaders;

  /// The port that the server is listening on.
  ///
  /// This is the actual port used when a port of zero is
  /// specified in the [bind] or [bindSecure] call.
  int get port;

  /// Sets the timeout, in seconds, for sessions of this [HttpServer].
  ///
  /// The default timeout is 20 minutes.
  set sessionTimeout(int timeout);

  /// Permanently stops this [HttpServer] from listening for new
  /// connections.  This closes the [Stream] of [HttpRequest]s with a
  /// done event. The returned future completes when the server is
  /// stopped. For a server started using [bind] or [bindSecure] this
  /// means that the port listened on no longer in use.
  ///
  /// If [force] is `true`, active connections will be closed immediately.
  Future close({bool force = false});

  /// A [HttpConnectionsInfo] object summarizing the number of
  /// current connections handled by the server.
  HttpConnectionsInfo connectionsInfo();

  /// Starts listening for HTTP requests on the specified [address] and
  /// [port].
  ///
  /// The [address] can either be a [String] or an
  /// [InternetAddress]. If [address] is a [String], [bind] will
  /// perform a [InternetAddress.lookup] and use the first value in the
  /// list. To listen on the loopback adapter, which will allow only
  /// incoming connections from the local host, use the value
  /// [InternetAddress.loopbackIPv4] or
  /// [InternetAddress.loopbackIPv6]. To allow for incoming
  /// connection from the network use either one of the values
  /// [InternetAddress.anyIPv4] or [InternetAddress.anyIPv6] to
  /// bind to all interfaces or the IP address of a specific interface.
  ///
  /// If an IP version 6 (IPv6) address is used, both IP version 6
  /// (IPv6) and version 4 (IPv4) connections will be accepted. To
  /// restrict this to version 6 (IPv6) only, use [v6Only] to set
  /// version 6 only. However, if the address is
  /// [InternetAddress.loopbackIPv6], only IP version 6 (IPv6) connections
  /// will be accepted.
  ///
  /// If [port] has the value 0 an ephemeral port will be chosen by
  /// the system. The actual port used can be retrieved using the
  /// [port] getter.
  ///
  /// The optional argument [backlog] can be used to specify the listen
  /// backlog for the underlying OS listen setup. If [backlog] has the
  /// value of 0 (the default) a reasonable value will be chosen by
  /// the system.
  ///
  /// The optional argument [shared] specifies whether additional HttpServer
  /// objects can bind to the same combination of `address`, `port` and `v6Only`.
  /// If `shared` is `true` and more `HttpServer`s from this isolate or other
  /// isolates are bound to the port, then the incoming connections will be
  /// distributed among all the bound `HttpServer`s. Connections can be
  /// distributed over multiple isolates this way.
  static Future<HttpServer> bind(address, int port,
          {int backlog = 0, bool v6Only = false, bool shared = false}) =>
      throw UnimplementedError();

  /// The [address] can either be a [String] or an
  /// [InternetAddress]. If [address] is a [String], [bind] will
  /// perform a [InternetAddress.lookup] and use the first value in the
  /// list. To listen on the loopback adapter, which will allow only
  /// incoming connections from the local host, use the value
  /// [InternetAddress.loopbackIPv4] or
  /// [InternetAddress.loopbackIPv6]. To allow for incoming
  /// connection from the network use either one of the values
  /// [InternetAddress.anyIPv4] or [InternetAddress.anyIPv6] to
  /// bind to all interfaces or the IP address of a specific interface.
  ///
  /// If an IP version 6 (IPv6) address is used, both IP version 6
  /// (IPv6) and version 4 (IPv4) connections will be accepted. To
  /// restrict this to version 6 (IPv6) only, use [v6Only] to set
  /// version 6 only.
  ///
  /// If [port] has the value 0 an ephemeral port will be chosen by
  /// the system. The actual port used can be retrieved using the
  /// [port] getter.
  ///
  /// The optional argument [backlog] can be used to specify the listen
  /// backlog for the underlying OS listen setup. If [backlog] has the
  /// value of 0 (the default) a reasonable value will be chosen by
  /// the system.
  ///
  /// If [requestClientCertificate] is true, the server will
  /// request clients to authenticate with a client certificate.
  /// The server will advertise the names of trusted issuers of client
  /// certificates, getting them from a [SecurityContext], where they have been
  /// set using [SecurityContext.setClientAuthorities].
  ///
  /// The optional argument [shared] specifies whether additional HttpServer
  /// objects can bind to the same combination of `address`, `port` and `v6Only`.
  /// If `shared` is `true` and more `HttpServer`s from this isolate or other
  /// isolates are bound to the port, then the incoming connections will be
  /// distributed among all the bound `HttpServer`s. Connections can be
  /// distributed over multiple isolates this way.

  static Future<HttpServer> bindSecure(
          address, int port, SecurityContext context,
          {int backlog = 0,
          bool v6Only = false,
          bool requestClientCertificate = false,
          bool shared = false}) =>
      throw UnimplementedError();
}

abstract class HttpSession implements Map {
  /// The id of the current session.
  String get id;

  /// Whether the session has not yet been sent to the client.
  bool get isNew;

  /// Sets a callback that will be called when the session is timed out.
  ///
  /// Calling this again will overwrite the previous value.
  set onTimeout(void Function() callback);

  /// Destroys the session.
  ///
  /// This terminates the session and any further
  /// connections with this id will be given a new id and session.
  void destroy();
}

class RedirectException implements HttpException {
  @override
  final String message;
  final List<RedirectInfo> redirects;

  const RedirectException(this.message, this.redirects);

  @override
  Uri get uri => redirects.last.location;

  @override
  String toString() => 'RedirectException: $message';
}

/// Redirect information.
abstract class RedirectInfo {
  /// Returns the location for the redirect.
  Uri get location;

  /// Returns the method used for the redirect.
  String get method;

  /// Returns the status code used for the redirect.
  int get statusCode;
}
