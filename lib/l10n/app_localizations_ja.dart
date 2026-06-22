// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Arcana Shop';

  @override
  String get allCategories => 'すべて';

  @override
  String get curatedForYou => 'おすすめ商品';

  @override
  String get freshStockDrops => '新着在庫';

  @override
  String get loadProductsError => '商品を読み込めませんでした';

  @override
  String get retry => '再試行';

  @override
  String get emptyProducts => 'このカテゴリには商品がありません';

  @override
  String get loadError => '商品を読み込めませんでした';

  @override
  String get homeNavLabel => 'ホーム';

  @override
  String get notificationsNavLabel => '通知';

  @override
  String get profileNavLabel => 'マイページ';

  @override
  String get notificationsTitle => '通知はまだありません';

  @override
  String get profileTitle => 'マイアカウント';

  @override
  String get chat => 'チャット';
}
