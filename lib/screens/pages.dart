import 'package:flutter/material.dart';
const darkBg = Color(0xFF0A003D);
const accent = Color(0xFFFF8C00);

class BasePage extends StatelessWidget {
  final String title;
  final Widget? child;
  const BasePage(this.title, {this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: accent)),
        iconTheme: const IconThemeData(color: accent),
      ),
      body: Center(child: child ?? Text(title, style: const TextStyle(color: Colors.white))),
    );
  }
}

class HomePage extends BasePage { const HomePage({Key? key}) : super('Home', key: key); }
class DarshanPage extends BasePage { const DarshanPage({Key? key}) : super('Darshan', key: key); }
class ChatPage extends BasePage { const ChatPage({Key? key}) : super('Chat', key: key); }
// class SevaPage extends BasePage { const SevaPage({Key? key}) : super('Seva', key: key); }
// class DaksinaPage extends BasePage { const DaksinaPage({Key? key}) : super('Daksina', key: key); }
