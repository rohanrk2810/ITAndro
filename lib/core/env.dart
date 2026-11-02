/// Gateway address. Override per build:
///   flutter run --dart-define=API_BASE_URL=https://api.20.235.49.81.sslip.io
/// The default is the Android emulator's alias for the PC's localhost.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

/// The website's address. Cloudflare's "verify you are human" check only runs on a host its key allows, so the
/// check page is loaded as if from here. Defaults to the API address with its leading "api." turned into "app.".
const _appOriginOverride = String.fromEnvironment('APP_ORIGIN');

String get appOrigin => _appOriginOverride.isNotEmpty ? _appOriginOverride : apiBaseUrl.replaceFirst('//api.', '//app.');
