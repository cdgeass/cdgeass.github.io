import 'package:flutter/material.dart';
import 'package:flutter_blog/adaptive_article_list.dart';
import 'package:flutter_blog/article.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/articles',
  routes: [
    GoRoute(
      path: '/articles',
      builder: (context, state) {
        return const AdaptiveArticleList();
      },
      routes: <RouteBase>[
        GoRoute(
          name: 'article',
          path: ':number',
          builder: (context, state) {
            final number = state.pathParameters['number'];
            return Article(
              number: number,
              nested: false,
            );
          },
        ),
      ],
    ),
  ],
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
