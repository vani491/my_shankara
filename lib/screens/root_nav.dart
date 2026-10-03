import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../app_drawer.dart';
import '../theme/colors.dart';
import 'ab_home_screen.dart';
import 'aa_guru_chatbot.dart';
import 'ac_darshan_intro_screen.dart';

class RootNav extends StatefulWidget {
  final int initialIndex;
  const RootNav({super.key, this.initialIndex = 0});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  late int _index;
  final _homeKey = GlobalKey<HomeScreenState>();
  // Single Scaffold/Drawer shared by every tab — the IndexedStack keeps each
  // tab's own widget state alive across switches, so per-tab Scaffolds each
  // ended up with their own drawer-open state (stale drawer reopening bug).
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  // The 4-step guided experience lives on its own pushed route (no bottom
  // nav, no drawer — exit only by completing it or the top-left back arrow).
  // `extra` lets the route call back into Home's diya-stats refresh without
  // Home needing to know how it was reached (tab Start button, or directly).
  void _goToDarshanFlow() {
    context.push(
      '/darshan',
      extra: () => _homeKey.currentState?.fetchDiyaStats(),
    );
  }
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
        isActive ? AppColors.navBarActiveIcon : Colors.white,
        BlendMode.srcIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeScreen(
        key: _homeKey,
        onGoToChat: () => setState(() => _index = 2),
        onGoToDarshan: _goToDarshanFlow, // "Begin Darshan" skips the intro tab
        onOpenDrawer: _openDrawer,
      ),
      DarshanIntroScreen(
        onOpenDrawer: _openDrawer,
        onStart: _goToDarshanFlow,
      ),
      ChatbotPage(onOpenDrawer: _openDrawer),
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
        key: _scaffoldKey,
        backgroundColor: AppColors.navBarBackground,
        drawer: AppDrawer(
          onProfileUpdated: () => _homeKey.currentState?.refreshDisplayName(),
        ),
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(canvasColor: AppColors.navBarBackground),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _index,
            onTap: (i) {
              setState(() => _index = i);
              if (i == 0) {
                _homeKey.currentState?.refreshDisplayName();
              }
            },
            selectedItemColor: AppColors.navBarActiveIcon,
            unselectedItemColor: Colors.white,
            items: [
              BottomNavigationBarItem(
                icon: _navIcon(
                  filled: 'assets/icons/nav/filled-home.svg',
                  unfilled: 'assets/icons/nav/unfilled-home.svg',
                  isActive: _index == 0,
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(
                  filled: 'assets/icons/nav/filled-lotus.svg',
                  unfilled: 'assets/icons/nav/unfilled-lotus.svg',
                  isActive: _index == 1,
                ),
                label: 'Darshan',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(
                  filled: 'assets/icons/nav/filled-chat.svg',
                  unfilled: 'assets/icons/nav/unfilled-chat.svg',
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