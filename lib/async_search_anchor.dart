import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blog/article_list.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AsyncSearchAnchor extends StatefulWidget {
  final ArticleSelected articleSelected;

  const AsyncSearchAnchor({super.key, required this.articleSelected});

  @override
  State<StatefulWidget> createState() => _AsyncSearchAnchorState();
}

class _AsyncSearchAnchorState extends State<AsyncSearchAnchor> {
  final dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<dynamic>> _search(String text) async {
    final queryParameters = {
      'q': '$text is:issue repo:cdgeass/cdgeass.github.io',
    };
    final url = Uri.https(
      'api.github.com',
      '/search/issues',
      queryParameters,
    );
    final resp = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    });
    final respBody = jsonDecode(resp.body) as Map<String, dynamic>;
    return respBody['items'] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor.bar(
      constraints: Theme.of(context)
              .searchBarTheme
              .constraints
              ?.copyWith(minWidth: double.infinity) ??
          const BoxConstraints(minWidth: double.infinity, minHeight: 56.0),
      barElevation: MaterialStateProperty.all(0),
      suggestionsBuilder: (context, controller) async {
        final items = await _search(controller.text);

        return items.map((item) {
          final title = item['title'];
          final createdAt = item['created_at'];
          return ListTile(
            title: Text(title),
            subtitle: Text(dateFormat.format(DateTime.parse(createdAt))),
            onTap: () {
              controller.closeView(controller.text);
              widget.articleSelected.call(item);
            },
          );
        }).toList();
      },
    );
  }
}
