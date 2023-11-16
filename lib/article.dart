import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

class Article extends StatefulWidget {
  final String? number;
  final Map<String, dynamic>? article;
  final bool nested;

  const Article({
    super.key,
    this.number,
    this.article,
    this.nested = true,
  });

  @override
  State<StatefulWidget> createState() => _ArticleState();
}

class _ArticleState extends State<Article> {
  late final String number;
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    number = widget.number ?? widget.article!['number'];
    if (widget.article != null) {
      future = Future.value(widget.article);
    } else {
      future = _load();
    }

    super.initState();
  }

  Future<Map<String, dynamic>> _load() async {
    final url = Uri.https(
      'api.github.com',
      'repos/cdgeass/cdgeass.github.io/issues/$number',
    );
    final resp = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    });

    return jsonDecode(resp.body) as dynamic;
  }

  @override
  Widget build(BuildContext context) {
    final articleWidget = FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final article = snapshot.data!;
        return Markdown(
          data: article['body'],
          selectable: true,
        );
      },
    );

    if (widget.nested) {
      return articleWidget;
    } else {
      return Scaffold(
        appBar: AppBar(),
        body: articleWidget,
      );
    }
  }
}
