import 'package:flutter/material.dart';

/// A simple "coming soon" screen. Used by features that don't have
/// their real UI built yet — swap it out page by page as you build.
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — coming soon')),
    );
  }
}