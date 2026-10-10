/// Turns a Firebase error into a title and a hint the user can act on
({String title, String hint}) describeError(Object? error) {
  final msg = '$error';
  if (msg.contains('permission-denied') || msg.contains('Permission denied')) {
    return (
      title: 'No access to detector data',
      hint: 'Publish the database rules: Firebase Console → '
          'Realtime Database → Rules. Then tap Retry.',
    );
  }
  if (msg.contains('network') || msg.contains('Network')) {
    return (
      title: 'No internet connection',
      hint: 'Check this phone\'s WiFi or mobile data, then tap Retry.',
    );
  }
  return (title: 'Can\'t reach the detector data', hint: msg);
}
