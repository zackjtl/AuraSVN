import 'package:flutter/material.dart';

class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.languageCode,
    required super.child,
  });

  final String languageCode;

  static String of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<LanguageScope>()
            ?.languageCode ??
        'zh_TW';
  }

  @override
  bool updateShouldNotify(LanguageScope oldWidget) {
    return oldWidget.languageCode != languageCode;
  }
}

String t(BuildContext context, String zhTw, String en) {
  return LanguageScope.of(context) == 'en' ? en : zhTw;
}
