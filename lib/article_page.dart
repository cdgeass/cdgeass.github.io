import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ArticlePage extends StatefulWidget {
  final Map<String, dynamic> article;

  const ArticlePage({super.key, required this.article});

  @override
  State<StatefulWidget> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Markdown(
        data: widget.article['body'],
        selectable: true,
      ),
    );
  }
}
