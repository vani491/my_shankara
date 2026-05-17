import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ab_home_screen.dart';
import 'aa_guru_chatbot.dart';
import 'ac_darshan_screen.dart';

const darkBg = Color(0xFF0A003D);
const accent = Color(0xFFFF8C00);

class RootNav extends StatefulWidget {
  final int initialIndex;
  const RootNav({super.key, this.initialIndex = 0});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Widget _navIcon({required String filled, required String unfilled, required bool isActive}) {
    return SvgPicture.asset(
      isActive ? filled : unfilled,
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(
        isActive ? accent : Colors.white,
        BlendMode.srcIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeScreen(
        onGoToChat: () => setState(() => _index = 2),
        onGoToDarshan: () => setState(() => _index = 1),
      ),
      DarshanScreen(
        onGoHome: () => setState(() => _index = 0),
      ),
      const ChatbotPage(),
    ];

    return PopScope(
      // Prevent default back (app close) when not on Home
      canPop: _index == 0, // ← Home pe ho toh app band hone do, warna nahi
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: darkBg,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(canvasColor: darkBg),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            selectedItemColor: accent,
            unselectedItemColor: Colors.white,
            items: [
              BottomNavigationBarItem(
                icon: _navIcon(
                  filled: 'assets/root-nav-icon/filled-home.svg',
                  unfilled: 'assets/root-nav-icon/unfilled-home.svg',
                  isActive: _index == 0,
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(
                  filled: 'assets/root-nav-icon/filled-lotus.svg',
                  unfilled: 'assets/root-nav-icon/unfilled-lotus.svg',
                  isActive: _index == 1,
                ),
                label: 'Darshan',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(
                  filled: 'assets/root-nav-icon/filled-chat.svg',
                  unfilled: 'assets/root-nav-icon/unfilled-chat.svg',
                  isActive: _index == 2,
                ),
                label: 'Chat',
              ),
            ],
          ),
        ),
      ),
    );
  }
}