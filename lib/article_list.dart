import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

typedef ArticleSelected = Function(Map<String, dynamic>);

class ArticleList extends StatefulWidget {
  final ArticleSelected articleSelected;
  final String? selected;

  const ArticleList({
    super.key,
    required this.articleSelected,
    this.selected,
  });

  @override
  State<ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends State<ArticleList> {
  final _controller = ScrollController();

  List<dynamic> _articles = [];

  String creator = 'cdgeass';
  int page = 1;
  int perPage = 30;
  late Future<dynamic> _future;
  bool hasReachMax = false;

  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    _future = _load(page);

    _controller.addListener(() {
      if (_controller.position.pixels == _controller.position.maxScrollExtent) {
        if (!hasReachMax) {
          setState(() {
            _future = _load(++page);
          });
        }
      }
    });

    super.initState();
  }

  Future<dynamic> _load(int page) async {
    final queryParameters = {
      'page': '$page',
      'per_page': '$perPage',
      'creator': creator,
    };
    final url = Uri.https(
      'api.github.com',
      'repos/cdgeass/cdgeass.github.io/issues',
      queryParameters,
    );
    final resp = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    });

    final articles = jsonDecode(resp.body) as List<dynamic>;
    if (articles.length < perPage) {
      hasReachMax = true;
    }

    _articles.addAll(articles);
    return _articles;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final articles = snapshot.data as List<dynamic>;
          _articles = articles;
        }

        bool loading = snapshot.connectionState == ConnectionState.waiting;

        return ListView.separated(
          controller: _controller,
          itemCount: _articles.length + 1,
          itemBuilder: (context, index) {
            if (index == _articles.length) {
              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Container();
            }

            final article = _articles[index];

            final title = article['title'];
            final number = article['number'].toString();
            final createdAt = article['created_at'];

            return ListTile(
              title: Text(title),
              subtitle: Text(dateFormat.format(DateTime.parse(createdAt))),
              selected: widget.selected == number,
              onTap: () {
                widget.articleSelected.call(article);
              },
            );
          },
          separatorBuilder: (context, index) {
            if (index == _articles.length) {
              return Container();
            }
            return const Divider(
              thickness: 1,
              height: 1,
            );
          },
        );
      },
    );
  }
}
