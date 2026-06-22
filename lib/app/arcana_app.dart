import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:arcana_online_shop_mobile/app/app_theme.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_language.dart';
import 'package:arcana_online_shop_mobile/features/storefront/presentation/storefront_shell_page.dart';
import 'package:arcana_online_shop_mobile/l10n/app_localizations.dart';

class ArcanaApp extends StatefulWidget {
  const ArcanaApp({super.key});

  @override
  State<ArcanaApp> createState() => _ArcanaAppState();
}

class _ArcanaAppState extends State<ArcanaApp> {
  StorefrontLanguage _language = StorefrontLanguage.thai;

  void _setLanguage(StorefrontLanguage language) {
    if (_language == language) return;
    setState(() => _language = language);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: _language.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StorefrontShellPage(
        selectedLanguage: _language,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}
