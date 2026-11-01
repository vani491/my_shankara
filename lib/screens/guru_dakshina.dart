import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/subscription_constants.dart';
import '../services/subscription_service.dart';
import '../theme/colors.dart';

/// Membership / Guru Dakshina page.
///
/// Supports 3 user states (guest / trial / active). Status comes from
/// Firestore; the price and the purchase flow come from [SubscriptionService].
enum MembershipStatus { guest, trial, active }

class GuruDakshinaPage extends StatefulWidget {
  const GuruDakshinaPage({super.key});

  @override
  State<GuruDakshinaPage> createState() => _GuruDakshinaPageState();
}

class _GuruDakshinaPageState extends State<GuruDakshinaPage> {
  static const int _trialLengthDays = 30;

  MembershipStatus _status = MembershipStatus.trial;
  int _trialDaysRemaining = _trialLengthDays;
  String _renewalDate = '';
  bool _isLoading = true;

  final SubscriptionService _subscription = SubscriptionService.instance;
  bool _refreshingAfterPurchase = false;

  /// Store price (e.g. "₹199.00"), a placeholder while it loads, or a dash if
  /// the product can't be found in the store.
  String get _localizedPrice =>
      _subscription.price ?? (_subscription.isLoadingProducts ? '…' : '—');

  String get _storeName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'Apple' : 'Google Play';

  @override
  void initState() {
    super.initState();
    _subscription.addListener(_onSubscriptionChanged);
    if (_subscription.productDetails == null &&
        !_subscription.isLoadingProducts) {
      _subscription.loadProducts();
    }
    _resolveStatus();
  }

  @override
  void dispose() {
    _subscription.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});

    final error = _subscription.errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      _subscription.clearError();
    }

    // Purchase confirmed → re-read Firestore so the page flips to Active.
    if (_subscription.isMember &&
        _status != MembershipStatus.active &&
        !_refreshingAfterPurchase) {
      _refreshingAfterPurchase = true;
      _resolveStatus().whenComplete(() => _refreshingAfterPurchase = false);
    }
  }

  Future<void> _resolveStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (mounted) {
          setState(() {
            _status = MembershipStatus.guest;
            _isLoading = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data == null) {
        if (mounted) {
          setState(() {
            _status = MembershipStatus.trial;
            _trialDaysRemaining = _trialLengthDays;
            _isLoading = false;
          });
        }
        return;
      }

      final subscriptionStatus = data['subscription_status'] as String?;

      if (subscriptionStatus == 'active') {
        // No renewal date is known client-side until server verification
        // writes one; the Active view shows "Active" when this is empty.
        final renewalTs = data['renewal_date'] as Timestamp?;
        final renewal = renewalTs != null
            ? DateFormat('d MMMM yyyy').format(renewalTs.toDate())
            : '';
        if (mounted) {
          setState(() {
            _status = MembershipStatus.active;
            _renewalDate = renewal;
            _isLoading = false;
          });
        }
        return;
      }

      final trialTs = data['trialStartDate'] as Timestamp?;
      if (trialTs != null) {
        final daysElapsed =
            DateTime.now().difference(trialTs.toDate()).inDays;
        final remaining =
        (_trialLengthDays - daysElapsed).clamp(0, _trialLengthDays);
        if (mounted) {
          setState(() {
            _status = MembershipStatus.trial;
            _trialDaysRemaining = remaining;
            _isLoading = false;
          });
        }
      } else {
        // Signed-in user with no trialStartDate yet — safe fallback.
        if (mounted) {
          setState(() {
            _status = MembershipStatus.trial;
            _trialDaysRemaining = _trialLengthDays;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('GuruDakshina: _resolveStatus error: $e');
      if (mounted) {
        setState(() {
          _status = MembershipStatus.trial;
          _trialDaysRemaining = _trialLengthDays;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Guru Dakshina'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _header(context),
              const SizedBox(height: 24),
              _statusChip(context),
              const SizedBox(height: 20),
              if (_status == MembershipStatus.guest) _guestView(context),
              if (_status == MembershipStatus.trial) _trialView(context),
              if (_status == MembershipStatus.active) _activeView(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: title + subtitle ──────────────────────────────────────────────
  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      'Support timeless wisdom for everyday life.',
      style: tt.bodyMedium?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.7),
        height: 1.5,
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────────────────────────
  Widget _statusChip(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    late String label;
    late Color color;
    switch (_status) {
      case MembershipStatus.guest:
        label = 'Guest';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case MembershipStatus.trial:
        if (_trialDaysRemaining <= 0) {
          label = 'Trial Expired';
          color = Theme.of(context).colorScheme.error; // red
        } else {
          label = 'Free Trial Active';
          color = AppColors.accent;
        }
        break;
      case MembershipStatus.active:
        label = 'Membership Active';
        color = AppColors.primary;
        break;
    }
    return Row(
      children: [
        Text(
          'Current status: ',
          style: tt.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── 1. GUEST VIEW ───────────────────────────────────────────────────────
  Widget _guestView(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Begin your sacred journey with a free trial.',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _membershipIncludes(context),
        const SizedBox(height: 28),
        _primaryButton(
          context,
          label: 'Start 30-Day Free Trial',
          onTap: () => context.go('/login'),
        ),
      ],
    );
  }

  // ── 2. TRIAL VIEW ─────────────────────────────────────────────────────────
  Widget _trialView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final expired = _trialDaysRemaining <= 0;
    final bannerColor = expired ? cs.error : AppColors.accent;
    final bannerText = expired
        ? 'Your free trial has ended'
        : _trialDaysRemaining == 1
        ? '1 day left in your free trial'
        : '$_trialDaysRemaining days left in your free trial';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trial days remaining banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: bannerColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bannerText,
                  style: tt.titleSmall?.copyWith(
                    color: bannerColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            expired
                ? 'Become a member to continue with full access.'
                : 'No automatic charge occurs when the trial ends.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: cs.outline.withValues(alpha: 0.2), height: 1),
        const SizedBox(height: 20),
        _membershipIncludes(context),
        const SizedBox(height: 24),
        _planCard(context),
        const SizedBox(height: 14),
        _purchaseDisclosure(context),
        const SizedBox(height: 22),
        _primaryButton(
          context,
          label: 'Begin Membership',
          onTap: _onBeginMembership,
          loading: _subscription.isPurchasing,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _subscription.isPurchasing
                ? null
                : _subscription.restorePurchases,
            child: Text(
              'Restore Purchases',
              style: tt.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. ACTIVE MEMBER VIEW ───────────────────────────────────────────────
  Widget _activeView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _planCard(context),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.event_available_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              _renewalDate.isEmpty ? 'Active' : 'Renews on $_renewalDate',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🙏', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Thank you for being part of MyShankara.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton(
          context,
          label: 'Manage Membership',
          onTap: _onManageMembership,
        ),
      ],
    );
  }

  // ── Reusable: "Your Membership Includes" row ────────────────────────────
  Widget _membershipIncludes(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: cs.outline.withValues(alpha: 0.2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Membership Includes',
          style: tt.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _includeItem(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Full Daily Darshan',
                  circleColor: AppColors.primary.withValues(alpha: 0.08),
                  iconColor: AppColors.primary,
                ),
              ),
              divider,
              Expanded(
                child: _includeItem(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Unlimited Guru Chat',
                  circleColor: AppColors.accent.withValues(alpha: 0.15),
                  iconColor: AppColors.accent,
                ),
              ),
              divider,
              Expanded(
                child: _includeItem(
                  context,
                  // TODO: swap for your diya icon/asset if you have one.
                  icon: Icons.local_fire_department_outlined,
                  label: 'Seva Diya Tracker',
                  circleColor: AppColors.primary.withValues(alpha: 0.08),
                  iconColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _includeItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color circleColor,
        required Color iconColor,
      }) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable: membership plan card ──────────────────────────────────────
  Widget _planCard(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MyShankara Membership',
            style: tt.titleMedium?.copyWith(
              color: AppColors.onPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _localizedPrice,
                style: tt.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_subscription.price != null) ...[
                const SizedBox(width: 6),
                Text(
                  '/month',
                  style: tt.bodyLarge?.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Reusable: purchase disclosure + legal links ─────────────────────────
  Widget _purchaseDisclosure(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final store = _storeName;
    final linkStyle = tt.bodySmall?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your subscription renews monthly at the displayed price until '
              'cancelled. Payment is processed through $store. Cancel anytime '
              'through $store before your next renewal.\n'
              'No prorated refunds; refunds are subject to $store policies and '
              'applicable law.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 20,
          children: [
            GestureDetector(
              onTap: () => context.push('/terms-of-service'),
              child: Text('Terms of Service', style: linkStyle),
            ),
            GestureDetector(
              onTap: () => context.push('/privacy-policy'),
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }

  // ── Reusable: primary button ────────────────────────────────────────────
  Widget _primaryButton(
      BuildContext context, {
        required String label,
        required VoidCallback onTap,
        bool loading = false,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  void _onBeginMembership() => _subscription.buy();

  Future<void> _onManageMembership() => _openUrl(
    defaultTargetPlatform == TargetPlatform.iOS
        ? SubscriptionConstants.iosManageUrl
        : SubscriptionConstants.androidManageUrl,
  );

  Future<void> _openUrl(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('GuruDakshina: could not open $url: $e');
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the link.")),
      );
    }
  }
}