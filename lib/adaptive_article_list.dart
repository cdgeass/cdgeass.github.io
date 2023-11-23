import 'package:flutter/material.dart';
import 'package:flutter_blog/article.dart';
import 'package:flutter_blog/article_list.dart';
import 'package:flutter_blog/async_search_anchor.dart';
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
    articleSelected(article) {
      final number = article['number'];
      context.goNamed(
        'article',
        pathParameters: {'number': '$number'},
      );
    }

    return Scaffold(
      appBar: AppBar(
        clipBehavior: Clip.none,
        shape: const StadiumBorder(),
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: AsyncSearchAnchor(
          articleSelected: articleSelected,
        ),
      ),
      body: ArticleList(
        articleSelected: articleSelected,
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
  String? _selected;
  Map<String, dynamic>? _selectedArticle;

  @override
  Widget build(BuildContext context) {
    articleSelected(article) {
      final number = article['number'].toString();
      setState(() {
        _selected = number;
        _selectedArticle = article;
      });
    }

    return Row(
      children: [
        Flexible(
          flex: 1,
          child: Scaffold(
            appBar: AppBar(
              clipBehavior: Clip.none,
              shape: const StadiumBorder(),
              titleSpacing: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              title: AsyncSearchAnchor(
                articleSelected: articleSelected,
              ),
            ),
            body: ArticleList(
              articleSelected: articleSelected,
              selected: _selected,
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
