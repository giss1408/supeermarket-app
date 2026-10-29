/// Route path constants and builders. Later tasks must use these instead of
/// hard-coding strings.
abstract final class Routes {
  static const offers = '/offers';
  static const flyerArchive = '/offers/flyers';
  static const lists = '/lists';
  static String listDetail(String id) => '/lists/${Uri.encodeComponent(id)}';
  static const stores = '/stores';
  static String storeDetail(int id) => '/stores/$id';
  static const account = '/account';
  static const pay = '/pay';
  static const signInPath = '/sign-in';
  static const registerPath = '/register';

  static String signIn({String? from}) => _withFrom(signInPath, from);
  static String register({String? from}) => _withFrom(registerPath, from);

  static String _withFrom(String path, String? from) {
    if (from == null || from.isEmpty) return path;
    return Uri(path: path, queryParameters: {'from': from}).toString();
  }
}
