import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/app/app_theme.dart';
import 'package:arcana_online_shop_mobile/features/storefront/presentation/storefront_shell_page.dart';

class ArcanaApp extends StatelessWidget {
  const ArcanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcana Shop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const StorefrontShellPage(),
    );
  }
}
