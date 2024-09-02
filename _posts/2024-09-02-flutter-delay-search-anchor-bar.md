---
layout: post
title: "Flutter搜索框延迟搜索"
date: "2024-09-02 13:37:00 +0800"
categories: flutter
---
```dart
Timer? _timer;

SearchAnchor.bar(
  suggestionsBuilder: (context, controller) async {
    if (_timer != null) {
      /// 如果有待执行的搜索则取消
      _timer!.cancel();
    }
    
    /// 使用Completer等待搜索结果
    final resultCompleter = Completer<dynamic>();
    /// 延迟300ms，等待输入完成再进行搜索
    _timer = Timer(const Duration(milliseconds: 300), () async {
      resultCompleter.complete(await search(controller.text)));
    });
    final result = await resultCompleter.future;

    /// 生成widgets;
    final widgets = [];

    return widgets;
  }
)
```
