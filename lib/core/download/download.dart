// Saves bytes as a file download in the browser (website). On phones this
// does nothing and returns false; the share sheet is used instead.
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
