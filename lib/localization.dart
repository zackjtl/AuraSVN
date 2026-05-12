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

String _t(BuildContext context, String zhTw, String en) {
  return LanguageScope.of(context) == 'en' ? en : zhTw;
}

String _localizedRuntimeText(BuildContext context, String text) {
  if (LanguageScope.of(context) != 'en') {
    return text;
  }
  const exact = {
    '尚未執行更新': 'Update not run yet',
    '尚未檢查後端狀態': 'Backend status not checked yet',
    '尚無本地資料': 'No local data yet',
    '已載入本地資料': 'Local data loaded',
    '設定已儲存': 'Settings saved',
    '正在讀取本地輸出資料': 'Reading local output data',
    '正在執行 SVN 增量更新': 'Running SVN incremental update',
    '更新完成，已重新載入資料': 'Update completed and data reloaded',
    '更新未完成': 'Update not completed',
  };
  return exact[text] ?? text;
}

String _localizedBackendSummary(BuildContext context, String summary) {
  switch (summary) {
    case '已連線':
      return _t(context, '已連線', 'Connected');
    case '檢查中':
      return _t(context, '檢查中', 'Checking');
    case '異常':
      return _t(context, '異常', 'Error');
    case '未連線':
      return _t(context, '未連線', 'Offline');
    default:
      return _t(context, '未確認', 'Unknown');
  }
}
