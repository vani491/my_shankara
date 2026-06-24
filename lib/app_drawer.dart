import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart'; // performSignOutActions, showSignOutConfirmDialog
import '../theme/colors.dart';
import '../services/user_name_cache.dart';
/// One shared navigation drawer used by every tab (Home, Darshan, Chat).
/// Cached preferred name so the drawer doesn't flicker on every open.


class AppDrawer extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  const AppDrawer({super.key, this.onProfileUpdated});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _preferredName = UserNameCache.value;
  bool get _isGuest =>
      FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

  @override
  void initState() {
    super.initState();
    _refreshName();
  }

  Future<void> _refreshName() async {
    final resolved = await UserNameCache.refresh();
    if (mounted && _preferredName != resolved) {
      setState(() => _preferredName = resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),

          // ── Nav items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [


                  _drawerItem(
                    context,
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () async {
                      Navigator.pop(context);
                      await context.push('/profile');
                      await _refreshName();
                      widget.onProfileUpdated?.call();
                    },
                  ),
                _drawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                _drawerItem(
                  context,
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Guru Dakshina',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/guru-dakshina');
                  },
                ),
                _drawerItem(
                  context,
                  icon: Icons.share_outlined,
                  label: 'Share Darshan',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/share-darshan');
                  },
                ),
                _drawerItem(
                  context,
                  icon: Icons.info_outline,
                  label: 'About MyShankara',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/about');
                  },
                ),
                _drawerItem(
                  context,
                  icon: Icons.support_agent_outlined,
                  label: 'Contact Support',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/support');
                  },
                ),
                _drawerItem(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/privacy-policy');
                  },
                ),
                _drawerItem(
                  context,
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/terms-of-service');
                  },
                ),
              ],
            ),
          ),

          // ── Sign out / Back to Sign In pinned at bottom ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            child: Column(
              children: [
                Divider(color: AppColors.outline.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                _drawerItem(
                  context,
                  icon: Icons.logout,
                  label: _isGuest ? 'Back to Sign In' : 'Sign Out',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    if (_isGuest) {
                      context.go('/login');
                    } else {
                      showSignOutConfirmDialog(
                        context,
                        onConfirm: performSignOutActions,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child : SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              // Avatar — left
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 2.5),
                ),
                child: const CircleAvatar(
                  radius: 32,
                  backgroundImage: AssetImage('assets/ic_user_profile.jpeg'),
                ),
              ),
              const SizedBox(width: 16),

              // Greeting + name — right side
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isGuest ? 'Welcome,' : 'Namaste,',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isGuest ? 'Sishya' : _preferredName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        bool isDestructive = false,
      }) {
    final theme = Theme.of(context);
    final color = isDestructive ? theme.colorScheme.error : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isDestructive
            ? theme.colorScheme.error.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!isDestructive)
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurface.withValues(alpha: 0.3),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}