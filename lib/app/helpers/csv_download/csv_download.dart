/// Picks the right "save this CSV text as a file" implementation for the
/// current platform. Web is checked before IO, since a web build defines
/// dart.library.html but not dart.library.io.
export 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart'
    if (dart.library.io) 'csv_download_io.dart';