import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blog/article_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<dynamic> _future;

  final dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    _future = _load();

    super.initState();
  }

  Future<dynamic> _load() async {
    final url =
        Uri.https('api.github.com', 'repos/cdgeass/cdgeass.github.io/issues');
    final resp = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    });

    return jsonDecode(resp.body) as dynamic;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final articles = snapshot.data as List<dynamic>;
          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];

              final title = article['title'];
              final createdAt = article['created_at'];

              return ListTile(
                title: Text(title),
                subtitle: Text(dateFormat.format(DateTime.parse(createdAt))),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return ArticlePage(article: article);
                  }));
                },
              );
            },
          );
        },
      ),
    );
  }
}
