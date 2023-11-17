import 'package:flutter/material.dart';
import 'package:flutter_blog/article.dart';
import 'package:flutter_blog/article_list.dart';
import 'package:go_router/go_router.dart';

class AdaptiveArticleList extends StatelessWidget {
  const AdaptiveArticleList({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= 600) {
      return const NarrowArticleList();
    } else {
      return const WideArticleList();
    }
  }
}

class NarrowArticleList extends StatelessWidget {
  const NarrowArticleList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ArticleList(
        articleSelected: (article) {
          final number = article['number'];
          context.goNamed(
            'article',
            pathParameters: {'number': '$number'},
          );
        },
      ),
    );
  }
}

class WideArticleList extends StatefulWidget {
  const WideArticleList({super.key});

  @override
  State<StatefulWidget> createState() => _WideArticleListState();
}

class _WideArticleListState extends State<WideArticleList> {
  Map<String, dynamic>? _selectedArticle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 1,
          child: Scaffold(
            appBar: AppBar(),
            body: ArticleList(
              articleSelected: (article) {
                setState(() {
                  _selectedArticle = article;
                });
              },
            ),
          ),
        ),
        if (_selectedArticle != null)
          Flexible(
            flex: 2,
            child: Builder(
              builder: (context) {
                return Article(
                  key: ValueKey(_selectedArticle!['number']),
                  number: '${_selectedArticle!['number']}',
                  article: _selectedArticle,
                );
              },
            ),
          )
      ],
    );
  }
}
