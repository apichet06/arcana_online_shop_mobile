// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Arcana Shop';

  @override
  String get allCategories => 'All';

  @override
  String get curatedForYou => 'Curated for you';

  @override
  String get freshStockDrops => 'Fresh stock drops';

  @override
  String get loadProductsError => 'Could not load products';

  @override
  String get retry => 'Retry';

  @override
  String get emptyProducts => 'No products in this category yet';

  @override
  String get loadError => 'Could not load products';

  @override
  String get homeNavLabel => 'Home';

  @override
  String get notificationsNavLabel => 'notifications';

  @override
  String get profileNavLabel => 'Me';

  @override
  String get notificationsTitle => 'No notifications yet';

  @override
  String get profileTitle => 'My account';

  @override
  String get chat => 'Chat';
}
