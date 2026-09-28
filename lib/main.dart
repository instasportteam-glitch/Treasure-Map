import 'package:flutter/material.dart';

import 'features/webview/view/webview_page.dart';

void main() {
  runApp(const TreasureMapApp());
}

class TreasureMapApp extends StatelessWidget {
  const TreasureMapApp({super.key});

  // Replace with your URL.
  static const startUrl = 'https://gamesrc.huntresmap.store/';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Treasure Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kDarkPurple,
      ),
      home: const WebViewPage(url: startUrl),
    );
  }
}
