import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether the browser refuses a request from this page to [uri] as mixed
/// content: a page served over HTTPS may not load an `http://` address, a
/// server on the local network included, and the browser blocks it before
/// it is sent. The machine itself (localhost, 127.0.0.1, ::1) is exempt.
/// Always false outside the browser. [web] and [page] are the running
/// platform and the page's address, for tests.
bool isBlockedMixedContent(Uri uri, {bool web = kIsWeb, Uri? page}) =>
    web &&
    (page ?? Uri.base).scheme == 'https' &&
    uri.scheme == 'http' &&
    !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);

/// What to tell the user about an address [isBlockedMixedContent] refuses.
const mixedContentMessage =
    'This page is served over HTTPS, so the browser blocks http:// '
    'addresses. Use the https:// address of the server.';
