/// Gateway address. Override per build: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
/// The default is the Android emulator's alias for the PC's localhost.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
